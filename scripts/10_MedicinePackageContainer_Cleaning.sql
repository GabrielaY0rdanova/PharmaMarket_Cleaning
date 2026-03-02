-- =================================================
-- 10_MedicinePackageContainer_Cleaning.sql
-- Cleans the Medicine_PackageContainer table in PharmaMarketAnalytics_Clean
--
-- STRUCTURE: 22,707 rows
--   Child table of Medicine — one row per container option per medicine.
--   PackageContainer_ID : surrogate PK created by ETL
--   Brand_ID            : FK to Medicine
--   Container_Size      : volume or placeholder string — NULL for Format B
--   Unit_Price          : price per unit — NULL for placeholder rows
--   Container_Type      : derived category column — e.g. Bottle, Vial, Tube
--
-- FORMAT B (13,496): Unit-priced medicines — Container_Size NULL, Unit_Price populated.
--   These medicines have no rows in Medicine_PackageSize.
-- FORMAT MIXED (9,172): Container medicines — both Container_Size and Unit_Price
--   populated. ETL design assumed Unit_Price would be NULL for these, but source
--   data had unit pricing alongside container size. Data is correct as-is.
-- FORMAT PLACEHOLDER (39): No pricing data — Container_Size contains the literal
--   string "Price Unavailable" or "Not for sale", Unit_Price NULL. Accepted as-is;
--   strings carry meaningful context and are not cleaning errors.
--   6 of these 39 rows are upstream Medicine duplicates (Brand_IDs 3952, 9027, 13603)
--   consistent with the known artifact documented in 08_Medicine_Cleaning.sql.
--
-- FINDINGS SUMMARY:
--   No cleaning required. All inspection checks passed.
--   Container_Type populated by ETL with 0 NULLs and only 3 N/A rows
--   (250 mg x2, 500 mg x1 — plain quantity strings with no container keyword).
--
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- =================================================
-- INSPECTION
-- =================================================

-- Full table preview
SELECT TOP 20 *
FROM Medicine_PackageContainer
ORDER BY PackageContainer_ID;

-- Row count
SELECT COUNT(*) AS Count
FROM Medicine_PackageContainer;

-- NULL profile — Container_Size, Unit_Price, Container_Type
-- Expected: 13,496 NULL Container_Size (Format B), 39 NULL Unit_Price (placeholders), 0 NULL Container_Type
SELECT
    SUM(CASE WHEN Container_Size  IS NULL THEN 1 ELSE 0 END) AS Null_Container_Size,
    SUM(CASE WHEN Unit_Price      IS NULL THEN 1 ELSE 0 END) AS Null_Unit_Price,
    SUM(CASE WHEN Container_Type  IS NULL THEN 1 ELSE 0 END) AS Null_Container_Type
FROM Medicine_PackageContainer;

-- Format breakdown — actual distribution of Container_Size / Unit_Price combinations
-- Format B           : Container_Size IS NULL,     Unit_Price IS NOT NULL  → 13,496
-- Format Mixed       : Container_Size IS NOT NULL, Unit_Price IS NOT NULL  → 9,172
-- Format Placeholder : Container_Size IS NOT NULL, Unit_Price IS NULL      → 39
--   (Container_Size contains 'Price Unavailable' or 'Not for sale', not real values)
SELECT
    CASE
        WHEN Container_Size IS NULL     AND Unit_Price IS NOT NULL THEN 'Format B — unit-priced'
        WHEN Container_Size IS NOT NULL AND Unit_Price IS NOT NULL THEN 'Format Mixed — both populated'
        WHEN Container_Size IS NOT NULL AND Unit_Price IS NULL     THEN 'Format Placeholder — no pricing'
        WHEN Container_Size IS NULL     AND Unit_Price IS NULL     THEN 'Empty — both NULL'
    END AS Format_Type,
    COUNT(*) AS Row_Count
FROM Medicine_PackageContainer
GROUP BY
    CASE
        WHEN Container_Size IS NULL     AND Unit_Price IS NOT NULL THEN 'Format B — unit-priced'
        WHEN Container_Size IS NOT NULL AND Unit_Price IS NOT NULL THEN 'Format Mixed — both populated'
        WHEN Container_Size IS NOT NULL AND Unit_Price IS NULL     THEN 'Format Placeholder — no pricing'
        WHEN Container_Size IS NULL     AND Unit_Price IS NULL     THEN 'Empty — both NULL'
    END;

-- Duplicate check — Brand_ID + Container_Size + Unit_Price
-- Expected: 3 groups — Brand_IDs 3952, 9027, 13603 (upstream Medicine duplicates)
SELECT
    Brand_ID,
    Container_Size,
    Unit_Price,
    COUNT(*) AS Count
FROM Medicine_PackageContainer
GROUP BY
    Brand_ID,
    Container_Size,
    Unit_Price
HAVING COUNT(*) > 1;

-- Container_Size distribution — by frequency (most common first)
-- Review for outliers or implausible values
SELECT
    Container_Size,
    COUNT(*) AS Frequency
FROM Medicine_PackageContainer
GROUP BY Container_Size
ORDER BY Frequency DESC;

-- Container_Type distribution — review for unexpected categories or N/A counts
-- Expected N/A: 3 rows (250 mg x2, 500 mg x1) — plain quantity strings with no container keyword
SELECT
    Container_Type,
    COUNT(*) AS Frequency
FROM Medicine_PackageContainer
GROUP BY Container_Type
ORDER BY Frequency DESC;

-- Unit_Price range — review for implausible values
SELECT
    MIN(Unit_Price) AS Min_Price,
    MAX(Unit_Price) AS Max_Price,
    AVG(Unit_Price) AS Avg_Price
FROM Medicine_PackageContainer
WHERE Unit_Price IS NOT NULL;

-- Referential integrity — orphaned Brand_IDs not in Medicine
SELECT COUNT(*) AS Orphaned_Brand_IDs
FROM Medicine_PackageContainer pc
LEFT JOIN Medicine m ON pc.Brand_ID = m.Brand_ID
WHERE m.Brand_ID IS NULL;

-- Spot check — TOP 20 joined to Medicine for Brand_Name and Strength
SELECT TOP 20
    pc.PackageContainer_ID,
    pc.Brand_ID,
    m.Brand_Name,
    m.Strength,
    pc.Container_Size,
    pc.Container_Type,
    pc.Unit_Price
FROM Medicine_PackageContainer pc
INNER JOIN Medicine m ON pc.Brand_ID = m.Brand_ID
ORDER BY pc.Brand_ID, pc.PackageContainer_ID;

-- =================================================
-- NO FIXES REQUIRED
-- =================================================
-- All inspection checks passed. Table accepted as-is.
-- The 3 duplicate groups (Brand_IDs 3952, 9027, 13603) are known
-- upstream artifacts documented in 08_Medicine_Cleaning.sql.
-- The 39 placeholder rows carry meaningful source context and
-- are not ETL parsing failures.
-- The 3 N/A Container_Type rows (250 mg, 500 mg) contain no
-- container keyword and cannot be categorised — accepted as-is.

-- =================================================
-- FINAL SUMMARY
-- =================================================

SELECT
    COUNT(*)                                                                    AS Total_Rows,
    SUM(CASE WHEN Container_Size IS NULL THEN 1 ELSE 0 END)                    AS Null_Container_Size,
    SUM(CASE WHEN Unit_Price     IS NULL THEN 1 ELSE 0 END)                    AS Null_Unit_Price,
    SUM(CASE WHEN Container_Type IS NULL THEN 1 ELSE 0 END)                    AS Null_Container_Type,
    (SELECT COUNT(*)
     FROM Medicine_PackageContainer pc
     LEFT JOIN Medicine m ON pc.Brand_ID = m.Brand_ID
     WHERE m.Brand_ID IS NULL)                                                  AS Orphaned_Brand_IDs,
    (SELECT COUNT(*) FROM (
         SELECT Brand_ID, Container_Size, Unit_Price
         FROM Medicine_PackageContainer
         GROUP BY Brand_ID, Container_Size, Unit_Price
         HAVING COUNT(*) > 1
     ) d)                                                                        AS Duplicate_Groups,
    -- Note: 3 expected — Brand_IDs 3952, 9027, 13603 upstream artifacts
    (SELECT COUNT(*)
     FROM Medicine_PackageContainer
     WHERE Container_Type = 'N/A')                                              AS NA_Container_Type
    -- Note: 3 expected — 250 mg x2, 500 mg x1
FROM Medicine_PackageContainer;
-- Expected: 22707 | 13496 | 39 | 0 | 0 | 3 | 3
GO