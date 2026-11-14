-- ============================================================
-- 03_fact.sql
-- Tabel fakta. Grain = satu baris item pesanan (order line item).
-- Jalankan SETELAH 02_dimensions.sql (butuh dimensi untuk FK).
--
-- Catatan desain:
--   * order_id           : degenerate dimension (tidak ada dim_order)
--   * order_date_key /
--     ship_date_key      : dua relasi ke dim_date (role-playing dimension)
--   * shipping_delay_days: GENERATED COLUMN -> jangan pernah di-INSERT/UPDATE manual
--   * Kategori & departemen diakses lewat dim_product -> dim_category -> dim_department
--     (sengaja TIDAK ada category_key di fakta)
-- ============================================================

USE bi;

CREATE TABLE IF NOT EXISTS fact_order_item (
  `order_item_sk`            int NOT NULL AUTO_INCREMENT COMMENT 'Surrogate primary key.',
  `order_item_id`            int NOT NULL COMMENT 'Natural key from source (Order Item Id).',
  `order_id`                 int NOT NULL COMMENT 'Parent order identifier - degenerate dimension (no separate dim_order).',
  `customer_key`             int NOT NULL COMMENT 'FK -> dim_customer.',
  `product_key`              int NOT NULL COMMENT 'FK -> dim_product.',
  `order_date_key`           int NOT NULL COMMENT 'FK -> dim_date for the order placement date.',
  `ship_date_key`            int DEFAULT NULL COMMENT 'FK -> dim_date for the shipment date. NULL when order not yet shipped.',
  `ship_territory_key`       int NOT NULL COMMENT 'FK -> dim_ship_territory.',
  `payment_type`             varchar(20) DEFAULT NULL COMMENT 'Transaction type: DEBIT | TRANSFER | CASH | PAYMENT.',
  `order_status`             varchar(30) DEFAULT NULL COMMENT 'COMPLETE | PENDING | CLOSED | PENDING_PAYMENT | CANCELED | PROCESSING | SUSPECTED_FRAUD | ON_HOLD | PAYMENT_REVIEW.',
  `shipping_mode`            varchar(30) DEFAULT NULL COMMENT 'Standard Class | First Class | Second Class | Same Day.',
  `delivery_status`          varchar(30) DEFAULT NULL COMMENT 'Advance shipping | Late delivery | Shipping on time | Shipping canceled.',
  `late_delivery_risk`       tinyint(1) NOT NULL DEFAULT '0' COMMENT '0 = not at risk, 1 = flagged as late delivery risk.',
  `days_shipping_real`       smallint DEFAULT NULL COMMENT 'Actual number of days taken to ship the order.',
  `days_shipment_scheduled`  smallint DEFAULT NULL COMMENT 'Originally scheduled number of days for shipment.',
  `shipping_delay_days`      smallint GENERATED ALWAYS AS ((`days_shipping_real` - `days_shipment_scheduled`)) STORED COMMENT 'Derived: actual - scheduled days. Positive = late, negative = early.',
  `order_item_quantity`      smallint NOT NULL DEFAULT '1' COMMENT 'Number of product units in this line item.',
  `order_item_product_price` decimal(12,2) NOT NULL COMMENT 'Unit list price before discount (Order Item Product Price).',
  `order_item_discount`      decimal(12,2) NOT NULL DEFAULT '0.00' COMMENT 'Absolute discount value applied to this line item.',
  `order_item_discount_rate` decimal(6,4) NOT NULL DEFAULT '0.0000' COMMENT 'Fractional discount rate, e.g. 0.05 = 5% (Order Item Discount Rate).',
  `order_item_total`         decimal(12,2) NOT NULL COMMENT 'Line total after discount (Order Item Total).',
  `sales`                    decimal(12,2) NOT NULL COMMENT 'Sales value - maps to the "Sales" column in source.',
  `order_item_profit_ratio`  decimal(8,4) DEFAULT NULL COMMENT 'Profit ratio for the line item (Order Item Profit Ratio).',
  `benefit_per_order`        decimal(12,2) DEFAULT NULL COMMENT 'Earnings per order placed (Benefit per order).',
  `order_profit_per_order`   decimal(12,2) DEFAULT NULL COMMENT 'Total profit for the whole order (Order Profit Per Order).',
  PRIMARY KEY (`order_item_sk`),
  UNIQUE KEY `uq_order_item_id` (`order_item_id`),
  KEY `fk_foi_customer` (`customer_key`),
  KEY `fk_foi_product` (`product_key`),
  KEY `fk_foi_ship_date` (`ship_date_key`),
  KEY `fk_foi_territory` (`ship_territory_key`),
  KEY `idx_foi_order_date` (`order_date_key`),
  CONSTRAINT `fk_foi_customer`   FOREIGN KEY (`customer_key`)       REFERENCES `dim_customer` (`customer_key`)             ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_foi_order_date` FOREIGN KEY (`order_date_key`)     REFERENCES `dim_date` (`date_key`)                     ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_foi_product`    FOREIGN KEY (`product_key`)        REFERENCES `dim_product` (`product_key`)               ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_foi_ship_date`  FOREIGN KEY (`ship_date_key`)      REFERENCES `dim_date` (`date_key`)                     ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `fk_foi_territory`  FOREIGN KEY (`ship_territory_key`) REFERENCES `dim_ship_territory` (`ship_territory_key`) ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_late_delivery_risk` CHECK (`late_delivery_risk` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Central fact table. Grain = one order line item. Measures cover sales, discount, profit, and shipping performance.';
