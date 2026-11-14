-- ============================================================
-- 00_create_database.sql
-- Membuat database `bi` (nama yang sama dengan yang dipakai di model Power BI).
-- Urutan eksekusi lengkap: lihat README.md
-- ============================================================

CREATE DATABASE IF NOT EXISTS bi
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_0900_ai_ci;

USE bi;
