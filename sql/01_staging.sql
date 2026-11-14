-- ============================================================
-- 01_staging.sql
-- Tabel staging (53 kolom, 1 baris = 1 baris CSV DataCo, tanpa transformasi)
-- Sumber data: DataCo Smart Supply Chain (Kaggle) - DataCoSupplyChainDataset.csv
-- Dataset TIDAK disertakan di repo (ukuran + lisensi): unduh dari Kaggle.
-- ============================================================

USE bi;

CREATE TABLE IF NOT EXISTS stg_supply_chain (
  `Type` varchar(50) DEFAULT NULL,
  `Days for shipping (real)` int DEFAULT NULL,
  `Days for shipment (scheduled)` int DEFAULT NULL,
  `Benefit per order` double DEFAULT NULL,
  `Sales per customer` double DEFAULT NULL,
  `Delivery Status` varchar(50) DEFAULT NULL,
  `Late_delivery_risk` int DEFAULT NULL,
  `Category Id` int DEFAULT NULL,
  `Category Name` varchar(50) DEFAULT NULL,
  `Customer City` varchar(50) DEFAULT NULL,
  `Customer Country` varchar(50) DEFAULT NULL,
  `Customer Email` varchar(50) DEFAULT NULL,
  `Customer Fname` varchar(50) DEFAULT NULL,
  `Customer Id` int DEFAULT NULL,
  `Customer Lname` varchar(50) DEFAULT NULL,
  `Customer Password` varchar(50) DEFAULT NULL,
  `Customer Segment` varchar(50) DEFAULT NULL,
  `Customer State` varchar(50) DEFAULT NULL,
  `Customer Street` varchar(50) DEFAULT NULL,
  `Customer Zipcode` int DEFAULT NULL,
  `Department Id` int DEFAULT NULL,
  `Department Name` varchar(50) DEFAULT NULL,
  `Latitude` double DEFAULT NULL,
  `Longitude` double DEFAULT NULL,
  `Market` varchar(50) DEFAULT NULL,
  `Order City` varchar(50) DEFAULT NULL,
  `Order Country` varchar(50) DEFAULT NULL,
  `Order Customer Id` int DEFAULT NULL,
  `order date (DateOrders)` varchar(50) DEFAULT NULL,
  `Order Id` int DEFAULT NULL,
  `Order Item Cardprod Id` int DEFAULT NULL,
  `Order Item Discount` double DEFAULT NULL,
  `Order Item Discount Rate` double DEFAULT NULL,
  `Order Item Id` int DEFAULT NULL,
  `Order Item Product Price` double DEFAULT NULL,
  `Order Item Profit Ratio` double DEFAULT NULL,
  `Order Item Quantity` int DEFAULT NULL,
  `Sales` double DEFAULT NULL,
  `Order Item Total` double DEFAULT NULL,
  `Order Profit Per Order` double DEFAULT NULL,
  `Order Region` varchar(50) DEFAULT NULL,
  `Order State` varchar(50) DEFAULT NULL,
  `Order Status` varchar(50) DEFAULT NULL,
  `Order Zipcode` int DEFAULT NULL,
  `Product Card Id` int DEFAULT NULL,
  `Product Category Id` int DEFAULT NULL,
  `Product Description` varchar(50) DEFAULT NULL,
  `Product Image` varchar(128) DEFAULT NULL,
  `Product Name` varchar(50) DEFAULT NULL,
  `Product Price` double DEFAULT NULL,
  `Product Status` int DEFAULT NULL,
  `shipping date (DateOrders)` varchar(50) DEFAULT NULL,
  `Shipping Mode` varchar(50) DEFAULT NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

-- ------------------------------------------------------------
-- LOAD CSV KE STAGING  (TEMPLATE - belum diuji dengan file asli; sesuaikan path)
--
-- Encoding: CSV DataCo umumnya latin-1 (ISO-8859-1). Jika dibaca sebagai UTF-8,
--           "Mexico" berakhir sebagai "M?xico" di dashboard. Pakai CHARACTER SET latin1.
-- Prasyarat: SET GLOBAL local_infile = 1; lalu koneksi dengan local-infile aktif.
--           Alternatif: Workbench > Table Data Import Wizard (pilih encoding latin1).
-- Zipcode kosong di CSV harus menjadi NULL (kolom bertipe INT), jadi dibaca lewat variabel.
-- Urutan kolom di bawah = urutan kolom CSV = urutan kolom tabel di atas.
-- ------------------------------------------------------------
-- TRUNCATE TABLE stg_supply_chain;
-- LOAD DATA LOCAL INFILE 'C:/path/ke/DataCoSupplyChainDataset.csv'
-- INTO TABLE stg_supply_chain
-- CHARACTER SET latin1
-- FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
-- LINES TERMINATED BY '\r\n'
-- IGNORE 1 LINES
-- (`Type`, `Days for shipping (real)`, `Days for shipment (scheduled)`, `Benefit per order`,
--  `Sales per customer`, `Delivery Status`, `Late_delivery_risk`, `Category Id`, `Category Name`,
--  `Customer City`, `Customer Country`, `Customer Email`, `Customer Fname`, `Customer Id`,
--  `Customer Lname`, `Customer Password`, `Customer Segment`, `Customer State`, `Customer Street`,
--  @customer_zip, `Department Id`, `Department Name`, `Latitude`, `Longitude`, `Market`,
--  `Order City`, `Order Country`, `Order Customer Id`, `order date (DateOrders)`, `Order Id`,
--  `Order Item Cardprod Id`, `Order Item Discount`, `Order Item Discount Rate`, `Order Item Id`,
--  `Order Item Product Price`, `Order Item Profit Ratio`, `Order Item Quantity`, `Sales`,
--  `Order Item Total`, `Order Profit Per Order`, `Order Region`, `Order State`, `Order Status`,
--  @order_zip, `Product Card Id`, `Product Category Id`, `Product Description`, `Product Image`,
--  `Product Name`, `Product Price`, `Product Status`, `shipping date (DateOrders)`, `Shipping Mode`)
-- SET `Customer Zipcode` = NULLIF(@customer_zip, ''),
--     `Order Zipcode`    = NULLIF(@order_zip, '');
