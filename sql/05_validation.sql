-- ============================================================
-- 05_validation.sql
-- Bukti integritas data setelah ETL. Jalankan per blok (Workbench hanya
-- menampilkan hasil query terakhir kalau semuanya dijalankan sekaligus).
-- ============================================================

USE bi;

-- ------------------------------------------------------------
-- A. Jumlah baris per tabel
-- ------------------------------------------------------------
SELECT 'stg_supply_chain'  AS table_name, COUNT(*) AS row_count FROM stg_supply_chain
UNION ALL SELECT 'dim_department',     COUNT(*) FROM dim_department
UNION ALL SELECT 'dim_category',       COUNT(*) FROM dim_category
UNION ALL SELECT 'dim_product',        COUNT(*) FROM dim_product
UNION ALL SELECT 'dim_customer',       COUNT(*) FROM dim_customer
UNION ALL SELECT 'dim_ship_territory', COUNT(*) FROM dim_ship_territory
UNION ALL SELECT 'dim_date',           COUNT(*) FROM dim_date
UNION ALL SELECT 'fact_order_item',    COUNT(*) FROM fact_order_item;
-- Ekspektasi: fact_order_item = stg_supply_chain = 180519.


-- ------------------------------------------------------------
-- B. NULL pada foreign key (semua harus 0)
--    ship_date_key nullable di skema, jadi dicek terpisah dan dilaporkan apa adanya.
-- ------------------------------------------------------------
SELECT
    SUM(customer_key       IS NULL) AS null_customer_key,
    SUM(product_key        IS NULL) AS null_product_key,
    SUM(ship_territory_key IS NULL) AS null_territory_key,
    SUM(order_date_key     IS NULL) AS null_order_date_key,
    SUM(ship_date_key      IS NULL) AS null_ship_date_key
FROM fact_order_item;


-- ------------------------------------------------------------
-- C. Selisih revenue staging vs fakta (harus 0.00)
-- ------------------------------------------------------------
SELECT
    ROUND((SELECT SUM(`Sales`) FROM stg_supply_chain), 2)                              AS stg_revenue,
    ROUND((SELECT SUM(sales)   FROM fact_order_item), 2)                               AS fact_revenue,
    ROUND((SELECT SUM(`Sales`) FROM stg_supply_chain)
        - (SELECT SUM(sales)   FROM fact_order_item), 2)                               AS diff;


-- ------------------------------------------------------------
-- D. Uji fan-out join: tiap join staging -> dimensi harus 1:1.
--    Jika satu baris staging cocok dengan >1 baris dimensi, ON DUPLICATE KEY pada
--    fakta menimpanya secara diam-diam: jumlah baris dan revenue tetap "benar"
--    padahal kunci dimensinya bisa salah. joined_rows HARUS = stg_rows.
-- ------------------------------------------------------------
SELECT 'dim_customer' AS joined_dim, COUNT(*) AS joined_rows,
       (SELECT COUNT(*) FROM stg_supply_chain) AS stg_rows
FROM stg_supply_chain s
JOIN dim_customer c ON c.customer_id = s.`Customer Id`
UNION ALL
SELECT 'dim_product', COUNT(*), (SELECT COUNT(*) FROM stg_supply_chain)
FROM stg_supply_chain s
JOIN dim_product p ON p.product_card_id = s.`Product Card Id`
UNION ALL
SELECT 'dim_ship_territory', COUNT(*), (SELECT COUNT(*) FROM stg_supply_chain)
FROM stg_supply_chain s
JOIN dim_ship_territory t
  ON  t.market        = s.`Market`
  AND t.order_region  = s.`Order Region`
  AND t.order_country = s.`Order Country`
  AND t.order_state   = s.`Order State`
  AND t.order_city    = s.`Order City`;


-- ------------------------------------------------------------
-- E. Tanggal: tidak ada yang gagal di-parse, dan kalender mencakup semua tanggal fakta
--    (kolom 1-2 harus 0; kolom 3-4 menunjukkan cakupan dim_date)
-- ------------------------------------------------------------
SELECT
    (SELECT SUM(STR_TO_DATE(`order date (DateOrders)`,    '%m/%d/%Y %H:%i') IS NULL) FROM stg_supply_chain) AS bad_order_dates,
    (SELECT SUM(STR_TO_DATE(`shipping date (DateOrders)`, '%m/%d/%Y %H:%i') IS NULL) FROM stg_supply_chain) AS bad_ship_dates,
    (SELECT MIN(full_date) FROM dim_date) AS dim_date_min,
    (SELECT MAX(full_date) FROM dim_date) AS dim_date_max;

-- Cek semantik kolom hari: 2016-01-04 adalah hari Senin -> harus Monday | 1
SELECT full_date, day_name, day_of_week, is_weekend FROM dim_date WHERE full_date = '2016-01-04';


-- ------------------------------------------------------------
-- F. (Informasi) Natural key dengan >1 varian atribut di staging.
--    ETL memakai "latest wins", jadi hasilnya deterministik; query ini hanya
--    menunjukkan seberapa sering varian terjadi (boleh > 0).
-- ------------------------------------------------------------
SELECT COUNT(*) AS customer_ids_with_multiple_variants FROM (
    SELECT `Customer Id`
    FROM (
        SELECT DISTINCT `Customer Id`, `Customer Fname`, `Customer Lname`, `Customer Email`,
               `Customer Segment`, `Customer City`, `Customer State`, `Customer Country`,
               `Customer Street`, `Customer Zipcode`, `Latitude`, `Longitude`
        FROM stg_supply_chain
    ) v
    GROUP BY `Customer Id`
    HAVING COUNT(*) > 1
) m;


-- ------------------------------------------------------------
-- G. Uji idempotensi: jalankan blok ini, jalankan ulang 04_etl_upsert.sql,
--    jalankan blok ini lagi. Semua nilai Checksum harus IDENTIK.
-- ------------------------------------------------------------
CHECKSUM TABLE dim_department, dim_category, dim_product, dim_customer,
               dim_ship_territory, dim_date, fact_order_item;
