-- ============================================================
-- 99_reset.sql
-- !! DESTRUKTIF !!  Menghapus fakta dan semua dimensi (staging TIDAK dihapus).
-- Dipakai untuk membangun ulang dari nol (mis. setelah staging di-load ulang dengan
-- encoding yang benar) atau untuk menguji bahwa repo bisa direproduksi.
-- Urutan drop = kebalikan urutan create (anak dulu, induk kemudian).
-- Setelah ini: 02_dimensions.sql -> 03_fact.sql -> 04_etl_upsert.sql -> 05_validation.sql
-- ============================================================

USE bi;

DROP TABLE IF EXISTS fact_order_item;
DROP TABLE IF EXISTS dim_product;
DROP TABLE IF EXISTS dim_category;
DROP TABLE IF EXISTS dim_department;
DROP TABLE IF EXISTS dim_customer;
DROP TABLE IF EXISTS dim_ship_territory;
DROP TABLE IF EXISTS dim_date;
