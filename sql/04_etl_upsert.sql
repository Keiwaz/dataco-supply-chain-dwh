-- ============================================================
-- 04_etl_upsert.sql
-- ETL: stg_supply_chain -> dimensi -> fakta
-- Strategi : INSERT ... ON DUPLICATE KEY UPDATE (UPSERT), idempoten
-- Prasyarat: 00-03 sudah dijalankan dan stg_supply_chain sudah terisi
-- Urutan   : department -> category -> customer -> product -> ship_territory -> date -> fact
--            (induk dulu baru anak; semua dimensi dulu baru fakta)
--
-- Prinsip yang dipakai:
--   * Natural key  = kolom UNIQUE di tiap dimensi -> dasar UPSERT
--   * "Latest wins": jika satu natural key punya beberapa varian atribut di staging,
--     varian dari baris pesanan TERBARU yang dipakai (ROW_NUMBER), sehingga hasilnya
--     deterministik dan hasil run ulang selalu identik.
--   * LEFT JOIN ke dimensi + kolom FK NOT NULL di fakta -> jika ada kunci yang tidak
--     ketemu, INSERT gagal dengan error (gagal keras, bukan data salah diam-diam).
--   * Tanggal staging bertipe teks 'm/d/YYYY H:mm' -> di-parse dengan STR_TO_DATE.
--   * shipping_delay_days adalah generated column -> tidak ikut di-INSERT.
--
-- Catatan: VALUES(col) di ON DUPLICATE KEY UPDATE ditandai deprecated sejak MySQL
-- 8.0.20 (hanya warning, tetap berfungsi di 8.0.x).
-- ============================================================

USE bi;
SET SESSION cte_max_recursion_depth = 10000;   -- dim_date dibangun dengan recursive CTE (>1000 hari)


-- ============================================================
-- SECTION 0: PRA-CEK STAGING  (ekspektasi DataCo: 180519 | 180519 | 0 | 0)
-- ============================================================
SELECT
    COUNT(*)                                                                       AS stg_rows,
    COUNT(DISTINCT `Order Item Id`)                                                AS distinct_order_items,
    SUM(STR_TO_DATE(`order date (DateOrders)`,    '%m/%d/%Y %H:%i') IS NULL)       AS unparsable_order_dates,
    SUM(STR_TO_DATE(`shipping date (DateOrders)`, '%m/%d/%Y %H:%i') IS NULL)       AS unparsable_ship_dates
FROM stg_supply_chain;


-- ============================================================
-- SECTION 1: dim_department
-- ============================================================
INSERT INTO dim_department (department_id, department_name)
SELECT DISTINCT
    `Department Id`,
    `Department Name`
FROM stg_supply_chain
WHERE `Department Id` IS NOT NULL
ON DUPLICATE KEY UPDATE
    department_name = VALUES(department_name);


-- ============================================================
-- SECTION 2: dim_category  (butuh department_key)
-- ============================================================
INSERT INTO dim_category (category_id, category_name, department_key)
SELECT DISTINCT
    s.`Category Id`,
    s.`Category Name`,
    d.department_key
FROM stg_supply_chain s
LEFT JOIN dim_department d
       ON d.department_id = s.`Department Id`
WHERE s.`Category Id` IS NOT NULL
ON DUPLICATE KEY UPDATE
    category_name  = VALUES(category_name),
    department_key = VALUES(department_key);


-- ============================================================
-- SECTION 3: dim_customer  (latest wins per customer_id)
-- ============================================================
INSERT INTO dim_customer (
    customer_id, customer_fname, customer_lname, customer_email, customer_segment,
    customer_city, customer_state, customer_country, customer_street, customer_zipcode,
    latitude, longitude
)
SELECT
    customer_id, fname, lname, email, segment,
    city, state, country, street, zipcode,
    lat, lon
FROM (
    SELECT
        `Customer Id`       AS customer_id,
        `Customer Fname`    AS fname,
        `Customer Lname`    AS lname,
        `Customer Email`    AS email,
        `Customer Segment`  AS segment,
        `Customer City`     AS city,
        `Customer State`    AS state,
        `Customer Country`  AS country,
        `Customer Street`   AS street,
        `Customer Zipcode`  AS zipcode,
        `Latitude`          AS lat,
        `Longitude`         AS lon,
        ROW_NUMBER() OVER (
            PARTITION BY `Customer Id`
            ORDER BY STR_TO_DATE(`order date (DateOrders)`, '%m/%d/%Y %H:%i') DESC,
                     `Order Item Id` DESC
        ) AS rn
    FROM stg_supply_chain
    WHERE `Customer Id` IS NOT NULL
) x
WHERE rn = 1
ON DUPLICATE KEY UPDATE
    customer_fname   = VALUES(customer_fname),
    customer_lname   = VALUES(customer_lname),
    customer_email   = VALUES(customer_email),
    customer_segment = VALUES(customer_segment),
    customer_city    = VALUES(customer_city),
    customer_state   = VALUES(customer_state),
    customer_country = VALUES(customer_country),
    customer_street  = VALUES(customer_street),
    customer_zipcode = VALUES(customer_zipcode),
    latitude         = VALUES(latitude),
    longitude        = VALUES(longitude);


-- ============================================================
-- SECTION 4: dim_product  (butuh category_key; latest wins per product_card_id)
-- ============================================================
INSERT INTO dim_product (
    product_card_id, product_name, product_description,
    product_price, product_status, category_key
)
SELECT
    x.product_card_id,
    x.product_name,
    x.product_description,
    x.product_price,
    x.product_status,
    c.category_key
FROM (
    SELECT
        `Product Card Id`           AS product_card_id,
        TRIM(`Product Name`)        AS product_name,
        `Product Description`       AS product_description,
        `Product Price`             AS product_price,
        `Product Status`            AS product_status,
        `Category Id`               AS category_id,
        ROW_NUMBER() OVER (
            PARTITION BY `Product Card Id`
            ORDER BY STR_TO_DATE(`order date (DateOrders)`, '%m/%d/%Y %H:%i') DESC,
                     `Order Item Id` DESC
        ) AS rn
    FROM stg_supply_chain
    WHERE `Product Card Id` IS NOT NULL
) x
LEFT JOIN dim_category c
       ON c.category_id = x.category_id
WHERE x.rn = 1
ON DUPLICATE KEY UPDATE
    product_name        = VALUES(product_name),
    product_description = VALUES(product_description),
    product_price       = VALUES(product_price),
    product_status      = VALUES(product_status),
    category_key        = VALUES(category_key);


-- ============================================================
-- SECTION 5: dim_ship_territory
--   Natural key = (market, region, country, state, city), sama dengan UNIQUE KEY tabel.
--   Semua kolom kunci wajib NOT NULL: NULL pada kolom UNIQUE tidak dianggap duplikat,
--   sehingga baris akan menggandakan diri setiap kali ETL dijalankan ulang.
--   shipping_mode TIDAK di sini: itu atribut transaksi, disimpan di fakta.
-- ============================================================
INSERT INTO dim_ship_territory (market, order_region, order_country, order_state, order_city, order_zipcode)
SELECT market, region, country, state, city, zipcode
FROM (
    SELECT
        `Market`        AS market,
        `Order Region`  AS region,
        `Order Country` AS country,
        `Order State`   AS state,
        `Order City`    AS city,
        `Order Zipcode` AS zipcode,
        ROW_NUMBER() OVER (
            PARTITION BY `Market`, `Order Region`, `Order Country`, `Order State`, `Order City`
            ORDER BY STR_TO_DATE(`order date (DateOrders)`, '%m/%d/%Y %H:%i') DESC,
                     `Order Item Id` DESC
        ) AS rn
    FROM stg_supply_chain
    WHERE `Market`        IS NOT NULL
      AND `Order Region`  IS NOT NULL
      AND `Order Country` IS NOT NULL
      AND `Order State`   IS NOT NULL
      AND `Order City`    IS NOT NULL
) x
WHERE rn = 1
ON DUPLICATE KEY UPDATE
    order_zipcode = VALUES(order_zipcode);


-- ============================================================
-- SECTION 6: dim_date
--   Kalender kontinu dari tanggal paling awal sampai paling akhir (order DAN ship date),
--   supaya FK order_date_key maupun ship_date_key selalu punya pasangan.
--   day_of_week mengikuti komentar kolom: 1 = Senin ... 7 = Minggu (ISO)
--   week_of_year = minggu ISO 1-53 (WEEKOFYEAR = WEEK(dt, 3)). Catatan: minggu ISO bisa jatuh
--                  di tahun kalender sebelumnya (mis. 2016-01-03 = minggu 53); untuk pelaporan
--                  mingguan lintas tahun gunakan YEARWEEK(full_date, 3), bukan (year, week_of_year).
-- ============================================================
INSERT INTO dim_date (
    date_key, full_date, `year`, `quarter`, `month`, month_name, week_of_year,
    day_of_month, day_of_week, day_name, is_weekend, is_month_start, is_month_end, `year_month`
)
WITH RECURSIVE bounds AS (
    SELECT MIN(d) AS d0, MAX(d) AS d1
    FROM (
        SELECT DATE(STR_TO_DATE(`order date (DateOrders)`,    '%m/%d/%Y %H:%i')) AS d FROM stg_supply_chain
        UNION ALL
        SELECT DATE(STR_TO_DATE(`shipping date (DateOrders)`, '%m/%d/%Y %H:%i')) AS d FROM stg_supply_chain
    ) u
),
cal AS (
    SELECT d0 AS dt, d1 FROM bounds
    UNION ALL
    SELECT dt + INTERVAL 1 DAY, d1 FROM cal WHERE dt < d1
)
SELECT
    CAST(DATE_FORMAT(dt, '%Y%m%d') AS UNSIGNED),
    dt,
    YEAR(dt),
    QUARTER(dt),
    MONTH(dt),
    MONTHNAME(dt),
    WEEKOFYEAR(dt),
    DAY(dt),
    WEEKDAY(dt) + 1,
    DAYNAME(dt),
    CASE WHEN WEEKDAY(dt) >= 5 THEN 1 ELSE 0 END,
    CASE WHEN DAY(dt) = 1 THEN 1 ELSE 0 END,
    CASE WHEN dt = LAST_DAY(dt) THEN 1 ELSE 0 END,
    DATE_FORMAT(dt, '%Y-%m')
FROM cal
ON DUPLICATE KEY UPDATE
    full_date      = VALUES(full_date),
    `year`         = VALUES(`year`),
    `quarter`      = VALUES(`quarter`),
    `month`        = VALUES(`month`),
    month_name     = VALUES(month_name),
    week_of_year   = VALUES(week_of_year),
    day_of_month   = VALUES(day_of_month),
    day_of_week    = VALUES(day_of_week),
    day_name       = VALUES(day_name),
    is_weekend     = VALUES(is_weekend),
    is_month_start = VALUES(is_month_start),
    is_month_end   = VALUES(is_month_end),
    `year_month`   = VALUES(`year_month`);


-- ============================================================
-- SECTION 7: fact_order_item
--   Natural key = order_item_id (UNIQUE uq_order_item_id).
--   shipping_delay_days TIDAK ada di daftar kolom: dihitung otomatis (generated column).
-- ============================================================
INSERT INTO fact_order_item (
    order_item_id, order_id,
    customer_key, product_key, order_date_key, ship_date_key, ship_territory_key,
    payment_type, order_status, shipping_mode, delivery_status, late_delivery_risk,
    days_shipping_real, days_shipment_scheduled,
    order_item_quantity, order_item_product_price, order_item_discount, order_item_discount_rate,
    order_item_total, sales, order_item_profit_ratio, benefit_per_order, order_profit_per_order
)
SELECT
    s.`Order Item Id`,
    s.`Order Id`,
    c.customer_key,
    p.product_key,
    CAST(DATE_FORMAT(STR_TO_DATE(s.`order date (DateOrders)`,    '%m/%d/%Y %H:%i'), '%Y%m%d') AS UNSIGNED),
    CAST(DATE_FORMAT(STR_TO_DATE(s.`shipping date (DateOrders)`, '%m/%d/%Y %H:%i'), '%Y%m%d') AS UNSIGNED),
    t.ship_territory_key,
    s.`Type`,
    s.`Order Status`,
    s.`Shipping Mode`,
    s.`Delivery Status`,
    s.`Late_delivery_risk`,
    s.`Days for shipping (real)`,
    s.`Days for shipment (scheduled)`,
    s.`Order Item Quantity`,
    s.`Order Item Product Price`,
    s.`Order Item Discount`,
    s.`Order Item Discount Rate`,
    s.`Order Item Total`,
    s.`Sales`,
    s.`Order Item Profit Ratio`,
    s.`Benefit per order`,
    s.`Order Profit Per Order`
FROM stg_supply_chain s
LEFT JOIN dim_customer c
       ON c.customer_id = s.`Customer Id`
LEFT JOIN dim_product p
       ON p.product_card_id = s.`Product Card Id`
LEFT JOIN dim_ship_territory t
       ON  t.market        = s.`Market`
       AND t.order_region  = s.`Order Region`
       AND t.order_country = s.`Order Country`
       AND t.order_state   = s.`Order State`
       AND t.order_city    = s.`Order City`
WHERE s.`Order Item Id` IS NOT NULL
ON DUPLICATE KEY UPDATE
    order_id                 = VALUES(order_id),
    customer_key             = VALUES(customer_key),
    product_key              = VALUES(product_key),
    order_date_key           = VALUES(order_date_key),
    ship_date_key            = VALUES(ship_date_key),
    ship_territory_key       = VALUES(ship_territory_key),
    payment_type             = VALUES(payment_type),
    order_status             = VALUES(order_status),
    shipping_mode            = VALUES(shipping_mode),
    delivery_status          = VALUES(delivery_status),
    late_delivery_risk       = VALUES(late_delivery_risk),
    days_shipping_real       = VALUES(days_shipping_real),
    days_shipment_scheduled  = VALUES(days_shipment_scheduled),
    order_item_quantity      = VALUES(order_item_quantity),
    order_item_product_price = VALUES(order_item_product_price),
    order_item_discount      = VALUES(order_item_discount),
    order_item_discount_rate = VALUES(order_item_discount_rate),
    order_item_total         = VALUES(order_item_total),
    sales                    = VALUES(sales),
    order_item_profit_ratio  = VALUES(order_item_profit_ratio),
    benefit_per_order        = VALUES(benefit_per_order),
    order_profit_per_order   = VALUES(order_profit_per_order);

-- Setelah selesai: jalankan 05_validation.sql
