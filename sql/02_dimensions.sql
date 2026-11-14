-- ============================================================
-- 02_dimensions.sql
-- Enam tabel dimensi. Urutan dibuat sesuai ketergantungan FK:
--   dim_department -> dim_category -> dim_product   (hierarki produk / "snowflake arm")
--   dim_customer, dim_date, dim_ship_territory       (dimensi star biasa)
-- Aman dijalankan ulang (CREATE TABLE IF NOT EXISTS). Untuk membangun dari nol: 99_reset.sql.
-- ============================================================

USE bi;

-- ------------------------------------------------------------
-- dim_department : puncak hierarki produk
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_department (
  `department_key`  int NOT NULL AUTO_INCREMENT COMMENT 'Surrogate primary key.',
  `department_id`   int NOT NULL COMMENT 'Natural key from source system (Department Id).',
  `department_name` varchar(100) NOT NULL COMMENT 'Human-readable department label (e.g. Fitness, Outdoors, Electronics).',
  PRIMARY KEY (`department_key`),
  UNIQUE KEY `uq_department_id` (`department_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Store department. Top of the product snowflake hierarchy.';

-- ------------------------------------------------------------
-- dim_category : anak dim_department
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_category (
  `category_key`   int NOT NULL AUTO_INCREMENT COMMENT 'Surrogate primary key.',
  `category_id`    int NOT NULL COMMENT 'Natural key from source system (Category Id).',
  `category_name`  varchar(100) NOT NULL COMMENT 'Human-readable category label (e.g. Sporting Goods, Apparel).',
  `department_key` int NOT NULL COMMENT 'FK -> dim_department. Establishes the snowflake arm.',
  PRIMARY KEY (`category_key`),
  UNIQUE KEY `uq_category_id` (`category_id`),
  KEY `fk_cat_dept` (`department_key`),
  CONSTRAINT `fk_cat_dept` FOREIGN KEY (`department_key`) REFERENCES `dim_department` (`department_key`)
    ON DELETE RESTRICT ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Product category. Child of dim_department in the snowflake hierarchy.';

-- ------------------------------------------------------------
-- dim_product : anak dim_category
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_product (
  `product_key`         int NOT NULL AUTO_INCREMENT COMMENT 'Surrogate primary key.',
  `product_card_id`     int NOT NULL COMMENT 'Natural key from source (Product Card Id / RFID).',
  `product_name`        varchar(255) NOT NULL COMMENT 'Product display name.',
  `product_description` text COMMENT 'Long-form product description.',
  `product_price`       decimal(12,2) NOT NULL COMMENT 'List price before any order-level discount.',
  `product_status`      tinyint(1) NOT NULL DEFAULT '0' COMMENT '0 = available, 1 = not available.',
  `category_key`        int NOT NULL COMMENT 'FK -> dim_category.',
  PRIMARY KEY (`product_key`),
  UNIQUE KEY `uq_product_card_id` (`product_card_id`),
  KEY `fk_prod_cat` (`category_key`),
  CONSTRAINT `fk_prod_cat` FOREIGN KEY (`category_key`) REFERENCES `dim_category` (`category_key`)
    ON DELETE RESTRICT ON UPDATE CASCADE,
  CONSTRAINT `chk_product_status` CHECK (`product_status` IN (0, 1))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Individual sellable product. Child of dim_category (snowflake arm).';

-- ------------------------------------------------------------
-- dim_customer
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_customer (
  `customer_key`     int NOT NULL AUTO_INCREMENT COMMENT 'Surrogate primary key.',
  `customer_id`      int NOT NULL COMMENT 'Natural key from source (Customer Id).',
  `customer_fname`   varchar(100) DEFAULT NULL COMMENT 'Customer first name.',
  `customer_lname`   varchar(100) DEFAULT NULL COMMENT 'Customer last name.',
  `customer_email`   varchar(255) DEFAULT NULL COMMENT 'Masked in source dataset (XXXXXXXXX) - kept for schema completeness.',
  `customer_segment` varchar(50) DEFAULT NULL COMMENT 'Consumer | Corporate | Home Office.',
  `customer_city`    varchar(100) DEFAULT NULL COMMENT 'City where the purchase is registered.',
  `customer_state`   varchar(100) DEFAULT NULL COMMENT 'State where the purchase is registered.',
  `customer_country` varchar(100) DEFAULT NULL COMMENT 'Country where the purchase is registered.',
  `customer_street`  varchar(255) DEFAULT NULL COMMENT 'Street address of the registered store.',
  `customer_zipcode` varchar(20) DEFAULT NULL COMMENT 'Zip/postal code of the registered store.',
  `latitude`         decimal(10,7) DEFAULT NULL COMMENT 'Latitude of the store where purchase is registered.',
  `longitude`        decimal(10,7) DEFAULT NULL COMMENT 'Longitude of the store where purchase is registered.',
  PRIMARY KEY (`customer_key`),
  UNIQUE KEY `uq_customer_id` (`customer_id`),
  CONSTRAINT `chk_customer_segment` CHECK (`customer_segment` IN ('Consumer', 'Corporate', 'Home Office'))
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Customer master. Lat/Lon represent the registered store location.';

-- ------------------------------------------------------------
-- dim_date : role-playing dimension (dipakai sebagai order date DAN ship date di fakta)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_date (
  `date_key`       int NOT NULL COMMENT 'Surrogate PK in YYYYMMDD integer format (e.g. 20160101).',
  `full_date`      date NOT NULL COMMENT 'Calendar date value.',
  `year`           smallint NOT NULL COMMENT 'Calendar year (e.g. 2016).',
  `quarter`        tinyint(1) NOT NULL COMMENT 'Quarter of year: 1-4.',
  `month`          tinyint(1) NOT NULL COMMENT 'Month of year: 1-12.',
  `month_name`     varchar(10) NOT NULL COMMENT 'Month name (e.g. January).',
  `week_of_year`   tinyint(1) NOT NULL COMMENT 'ISO week number: 1-53.',
  `day_of_month`   tinyint(1) NOT NULL COMMENT 'Day of month: 1-31.',
  `day_of_week`    tinyint(1) NOT NULL COMMENT 'Day of week: 1 (Mon) to 7 (Sun).',
  `day_name`       varchar(10) NOT NULL COMMENT 'Day name (e.g. Monday).',
  `is_weekend`     tinyint(1) NOT NULL COMMENT '1 = Saturday or Sunday, 0 = weekday.',
  `is_month_start` tinyint(1) NOT NULL COMMENT '1 = first day of month, 0 otherwise.',
  `is_month_end`   tinyint(1) NOT NULL COMMENT '1 = last day of month, 0 otherwise.',
  `year_month`     char(7) NOT NULL COMMENT 'YYYY-MM string for monthly grouping in reports (e.g. 2016-01).',
  PRIMARY KEY (`date_key`),
  UNIQUE KEY `uq_full_date` (`full_date`),
  CONSTRAINT `chk_day_of_month` CHECK (`day_of_month` BETWEEN 1 AND 31),
  CONSTRAINT `chk_day_of_week`  CHECK (`day_of_week` BETWEEN 1 AND 7),
  CONSTRAINT `chk_month`        CHECK (`month` BETWEEN 1 AND 12),
  CONSTRAINT `chk_quarter`      CHECK (`quarter` BETWEEN 1 AND 4),
  CONSTRAINT `chk_week_of_year` CHECK (`week_of_year` BETWEEN 1 AND 53)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Date dimension - generated as a continuous calendar from the earliest order/ship date to the latest.';

-- ------------------------------------------------------------
-- dim_ship_territory : tujuan pengiriman (shipping_mode ada di fakta, bukan di sini)
-- ------------------------------------------------------------
CREATE TABLE IF NOT EXISTS dim_ship_territory (
  `ship_territory_key` int NOT NULL AUTO_INCREMENT COMMENT 'Surrogate primary key.',
  `market`        varchar(50) DEFAULT NULL COMMENT 'Top-level geography: Africa | Europe | LATAM | Pacific Asia | USCA.',
  `order_region`  varchar(100) DEFAULT NULL COMMENT 'Sub-market region (e.g. Southeast Asia, Western Europe).',
  `order_country` varchar(100) DEFAULT NULL COMMENT 'Destination country of the order.',
  `order_state`   varchar(100) DEFAULT NULL COMMENT 'Destination state/province of the order.',
  `order_city`    varchar(100) DEFAULT NULL COMMENT 'Destination city of the order.',
  `order_zipcode` varchar(20) DEFAULT NULL COMMENT 'Destination zip/postal code.',
  PRIMARY KEY (`ship_territory_key`),
  UNIQUE KEY `uq_territory` (`market`, `order_region`, `order_country`, `order_state`, `order_city`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci
  COMMENT='Delivery destination hierarchy. Mirrors AdventureWorks SalesTerritory.';
