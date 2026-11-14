-- ============================================================
-- 06_dashboard_reconciliation.sql
-- Mencocokkan angka kartu/visual di dashboard Power BI dengan hasil SQL langsung dari warehouse.
-- Tujuan: setiap angka di README/LinkedIn/CV bisa dibuktikan dari query, bukan dari
-- pembacaan grafik. Measure DAX = perhitungan di Power BI; query ini adalah "kunci jawaban"-nya.
-- Jalankan per blok.
-- ============================================================

USE bi;

-- ------------------------------------------------------------
-- 1. KPI halaman Overall & Product Performance
--    Bandingkan satu per satu dengan kartu dashboard:
--      Total Revenue 36.78M | Total Profit 3.97M | Average Order Value 559.45 |
--      Total Customer 20.65K | Total Item Terjual 180.52K | Discount Rate 20.66 |
--      Profit Per Order 21.97
-- ------------------------------------------------------------
SELECT
    ROUND(SUM(sales), 2)                                     AS total_revenue,
    ROUND(SUM(order_profit_per_order), 2)                    AS total_profit_by_order_profit,
    ROUND(SUM(benefit_per_order), 2)                         AS total_profit_by_benefit,
    ROUND(SUM(sales) / COUNT(DISTINCT order_id), 2)          AS avg_order_value,
    COUNT(DISTINCT customer_key)                             AS total_customers,
    COUNT(*)                                                 AS order_lines,          -- baris item pesanan
    COUNT(DISTINCT order_id)                                 AS distinct_orders,      -- pesanan unik
    SUM(order_item_quantity)                                 AS units_sold,           -- jumlah unit terjual
    ROUND(AVG(order_item_discount), 2)                       AS avg_discount_amount,  -- nominal (USD) per item
    ROUND(AVG(order_item_discount_rate) * 100, 2)            AS avg_discount_rate_pct,-- persentase
    ROUND(AVG(order_profit_per_order), 2)                    AS avg_profit_per_line
FROM fact_order_item;
-- Periksa makna tiap kartu: "Total Item Terjual" = order_lines atau units_sold?
-- "Discount Rate" = avg_discount_amount (nominal) atau avg_discount_rate_pct (persen)?
-- Samakan label dashboard dengan definisi yang sebenarnya dipakai.


-- ------------------------------------------------------------
-- 2. Revenue per segmen pelanggan (dashboard: 19.10M | 11.17M | 6.52M)
-- ------------------------------------------------------------
SELECT c.customer_segment,
       ROUND(SUM(f.sales), 2)                                     AS revenue,
       ROUND(SUM(f.order_profit_per_order), 2)                    AS profit,
       ROUND(100 * SUM(f.sales) / SUM(SUM(f.sales)) OVER (), 1)   AS pct_revenue
FROM fact_order_item f
JOIN dim_customer c ON c.customer_key = f.customer_key
GROUP BY c.customer_segment
ORDER BY revenue DESC;


-- ------------------------------------------------------------
-- 3. Revenue, profit, margin per departemen (lewat hierarki produk ter-snowflake)
-- ------------------------------------------------------------
SELECT d.department_name,
       COUNT(*)                                                    AS order_lines,
       SUM(f.order_item_quantity)                                  AS units_sold,
       ROUND(SUM(f.sales), 2)                                      AS revenue,
       ROUND(SUM(f.order_profit_per_order), 2)                     AS profit,
       ROUND(100 * SUM(f.order_profit_per_order) / SUM(f.sales), 2) AS margin_pct,
       ROUND(100 * SUM(f.sales) / SUM(SUM(f.sales)) OVER (), 1)    AS pct_revenue
FROM fact_order_item f
JOIN dim_product    p ON p.product_key    = f.product_key
JOIN dim_category   c ON c.category_key   = p.category_key
JOIN dim_department d ON d.department_key = c.department_key
GROUP BY d.department_name
ORDER BY revenue DESC;


-- ------------------------------------------------------------
-- 4. Status pesanan; PENDING_PAYMENT dalam baris item, pesanan unik, dan nilai revenue
--    (slide: "39.832 pesanan, $8,1 juta": 39.832 kemungkinan adalah baris item, bukan pesanan unik)
-- ------------------------------------------------------------
SELECT order_status,
       COUNT(*)                                 AS order_lines,
       COUNT(DISTINCT order_id)                 AS distinct_orders,
       ROUND(SUM(sales), 2)                     AS revenue,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_lines
FROM fact_order_item
GROUP BY order_status
ORDER BY order_lines DESC;


-- ------------------------------------------------------------
-- 5. Pengiriman: status, moda, dan market
--    (dashboard: Late 98.977 = 54.8% | First Class 95.3% | Second 76.6% | Standard 38.1% | Same Day 45.7%)
-- ------------------------------------------------------------
SELECT delivery_status,
       COUNT(*)                                          AS order_lines,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)  AS pct
FROM fact_order_item
GROUP BY delivery_status
ORDER BY order_lines DESC;

SELECT shipping_mode,
       COUNT(*)                                                                AS order_lines,
       ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                        AS pct_volume,
       ROUND(100 * AVG(delivery_status = 'Late delivery'), 1)                  AS pct_late_by_status,
       ROUND(100 * AVG(late_delivery_risk), 1)                                 AS pct_late_by_risk_flag,
       ROUND(AVG(days_shipment_scheduled), 1)                                  AS avg_days_scheduled,
       ROUND(AVG(days_shipping_real), 2)                                       AS avg_days_real,
       ROUND(AVG(shipping_delay_days), 2)                                      AS avg_delay_days
FROM fact_order_item
GROUP BY shipping_mode
ORDER BY pct_late_by_status DESC;

SELECT t.market,
       COUNT(*)                                               AS order_lines,
       ROUND(100 * AVG(f.delivery_status = 'Late delivery'), 1) AS pct_late
FROM fact_order_item f
JOIN dim_ship_territory t ON t.ship_territory_key = f.ship_territory_key
GROUP BY t.market
ORDER BY pct_late DESC;


-- ------------------------------------------------------------
-- 6. Tren revenue per bulan (dasar klaim pertumbuhan tahunan; 2018 hanya Januari)
-- ------------------------------------------------------------
SELECT d.`year`, d.`month`, ROUND(SUM(f.sales), 2) AS revenue
FROM fact_order_item f
JOIN dim_date d ON d.date_key = f.order_date_key
GROUP BY d.`year`, d.`month`
ORDER BY d.`year`, d.`month`;

SELECT d.`year`, ROUND(SUM(f.sales), 2) AS revenue, COUNT(DISTINCT d.`month`) AS months_with_data
FROM fact_order_item f
JOIN dim_date d ON d.date_key = f.order_date_key
GROUP BY d.`year`
ORDER BY d.`year`;
