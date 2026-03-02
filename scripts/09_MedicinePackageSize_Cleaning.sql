-- =================================================
-- 09_MedicinePackageSize_Cleaning.sql
-- Cleans the Medicine_PackageSize table in PharmaMarketAnalytics_Clean
--
-- STRUCTURE: 14,349 rows
--   Child table of Medicine — one row per pack size option per medicine.
--   PackageSize_ID : surrogate PK created by ETL
--   Brand_ID       : FK to Medicine
--   Pack_Size      : unit count (e.g. 30, 100, 500)
--   Pack_Price     : price for that pack in BDT
--
-- FINDINGS SUMMARY:
--   No cleaning required. All inspection checks passed.
--   One known duplicate group (Brand_ID 20089, Unisaline Fruity, Pack_Size 20)
--   is a propagated artifact from 59 duplicate rows in the upstream Medicine table.
--   This is documented in 08_Medicine_Cleaning.sql and accepted as-is.
--   Max price of 278,400 BDT (Juparib 150mg, 120 tablets) is a high-cost
--   oncology drug (PARP inhibitor) — confirmed plausible, not an error.
--
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- =================================================
-- INSPECTION
-- =================================================

-- Full table preview
SELECT TOP 20 * FROM Medicine_PackageSize ORDER BY PackageSize_ID;

-- Row count
SELECT COUNT(*) AS Count FROM Medicine_PackageSize;

-- NULL check — Pack_Size and Pack_Price
SELECT
    SUM(CASE WHEN Pack_Size  IS NULL THEN 1 ELSE 0 END) AS Null_Pack_Size,
    SUM(CASE WHEN Pack_Price IS NULL THEN 1 ELSE 0 END) AS Null_Pack_Price
FROM Medicine_PackageSize;

-- Duplicate check — Brand_ID + Pack_Size + Pack_Price
-- Known result: 1 — Unisaline Fruity triplicate from upstream Medicine duplicate
SELECT Brand_ID, Pack_Size, Pack_Price, COUNT(*) AS Count
FROM Medicine_PackageSize
GROUP BY Brand_ID, Pack_Size, Pack_Price
HAVING COUNT(*) > 1;

-- Pack_Size distribution — by frequency (most common first)
SELECT
    Pack_Size,
    COUNT(*) AS Frequency
FROM Medicine_PackageSize
GROUP BY Pack_Size
ORDER BY Frequency DESC;

-- Pack_Price range — review for implausible values
SELECT
    MIN(Pack_Price) AS Min_Price,
    MAX(Pack_Price) AS Max_Price,
    AVG(Pack_Price) AS Avg_Price
FROM Medicine_PackageSize;

-- Spot check max price row
-- Result: Juparib 150mg Tablet, Pack_Size 120, Pack_Price 278,400 BDT
-- Juparib (olaparib) is a PARP inhibitor used in oncology — price confirmed plausible
SELECT
    ps.PackageSize_ID,
    ps.Brand_ID,
    m.Brand_Name,
    m.Strength,
    df.Dosage_Form_Name,
    ps.Pack_Size,
    ps.Pack_Price
FROM Medicine_PackageSize ps
INNER JOIN Medicine m ON ps.Brand_ID = m.Brand_ID
INNER JOIN Dosage_Form df ON m.Dosage_Form_ID = df.Dosage_Form_ID
WHERE ps.Pack_Price = (SELECT MAX(Pack_Price) FROM Medicine_PackageSize);

-- Referential integrity — orphaned Brand_IDs not in Medicine
SELECT COUNT(*) AS Orphaned_Brand_IDs
FROM Medicine_PackageSize ps
LEFT JOIN Medicine m ON ps.Brand_ID = m.Brand_ID
WHERE m.Brand_ID IS NULL;

-- Medicines with more than 3 pack sizes
-- ETL only handles up to 3 pack size blocks — any result here is unexpected
SELECT COUNT(*) AS Over_3_Pack_Sizes
FROM (
    SELECT Brand_ID, COUNT(*) AS cnt
    FROM Medicine_PackageSize
    GROUP BY Brand_ID
    HAVING COUNT(*) > 3
) d;

-- Pack size count distribution per medicine
SELECT
    Pack_Size_Count,
    COUNT(*) AS Medicine_Count
FROM (
    SELECT Brand_ID, COUNT(*) AS Pack_Size_Count
    FROM Medicine_PackageSize
    GROUP BY Brand_ID
) counts
GROUP BY Pack_Size_Count
ORDER BY Pack_Size_Count;

-- Spot check — join back to Medicine for context
SELECT TOP 20
    ps.PackageSize_ID,
    ps.Brand_ID,
    m.Brand_Name,
    m.Strength,
    ps.Pack_Size,
    ps.Pack_Price
FROM Medicine_PackageSize ps
INNER JOIN Medicine m ON ps.Brand_ID = m.Brand_ID
ORDER BY ps.Brand_ID, ps.Pack_Size;

-- =================================================
-- NO FIXES REQUIRED
-- =================================================
-- All inspection checks passed. Table accepted as-is.
-- The single duplicate group (Unisaline Fruity) is a known upstream
-- artifact documented in 08_Medicine_Cleaning.sql.

-- =================================================
-- FINAL SUMMARY
-- =================================================

SELECT
    COUNT(*)                                                                AS Total_Rows,
    SUM(CASE WHEN Pack_Size  IS NULL THEN 1 ELSE 0 END)                    AS Null_Pack_Size,
    SUM(CASE WHEN Pack_Price IS NULL THEN 1 ELSE 0 END)                    AS Null_Pack_Price,
    (SELECT COUNT(*)
     FROM Medicine_PackageSize ps
     LEFT JOIN Medicine m ON ps.Brand_ID = m.Brand_ID
     WHERE m.Brand_ID IS NULL)                                              AS Orphaned_Brand_IDs,
    (SELECT COUNT(*) FROM (
         SELECT Brand_ID, Pack_Size, Pack_Price
         FROM Medicine_PackageSize
         GROUP BY Brand_ID, Pack_Size, Pack_Price
         HAVING COUNT(*) > 1
     ) d)                                                                   AS Duplicate_Groups
FROM Medicine_PackageSize;
-- Expected: 14349 | 0 | 0 | 0 | 1
-- Note: 1 duplicate group expected — Unisaline Fruity upstream artifact
GO