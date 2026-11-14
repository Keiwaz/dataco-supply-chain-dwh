# SQL: DataCo Supply Chain Data Warehouse (MySQL 8)

Model dimensional: 1 tabel fakta (`fact_order_item`, grain = item pesanan) dan 6 dimensi.
Hierarki produk dinormalisasi (`dim_product` -> `dim_category` -> `dim_department`), dimensi lain
terhubung langsung ke fakta (star). `dim_date` dipakai dua kali (order date dan ship date).

## Urutan eksekusi

| # | File | Isi |
|---|------|-----|
| 0 | `00_create_database.sql` | membuat database `bi` |
| 1 | `01_staging.sql` | tabel staging + template load CSV (encoding latin-1) |
| 2 | `02_dimensions.sql` | DDL 6 dimensi (urut sesuai FK) |
| 3 | `03_fact.sql` | DDL tabel fakta |
| 4 | `04_etl_upsert.sql` | ETL UPSERT: staging -> dimensi -> fakta |
| 5 | `05_validation.sql` | validasi integritas, uji fan-out join, uji idempotensi |
| 6 | `06_dashboard_reconciliation.sql` | mencocokkan angka dashboard Power BI dengan SQL |
| 99 | `99_reset.sql` | (destruktif) menghapus fakta + dimensi untuk build ulang |

## Prasyarat
- MySQL 8.0 atau lebih baru (memakai window function, recursive CTE, generated column, CHECK).
- Dataset `DataCoSupplyChainDataset.csv` dari Kaggle (tidak disertakan di repo).
- Isi `stg_supply_chain` dulu (lihat template di `01_staging.sql`), baru jalankan 04.

## Idempoten
`04_etl_upsert.sql` boleh dijalankan berulang kali: hasilnya identik (jumlah baris dan checksum
tidak berubah). Buktikan dengan blok G di `05_validation.sql`.
