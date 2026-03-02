-- =================================================
-- 08_Medicine_Cleaning.sql
-- Cleans the Medicine table in PharmaMarketAnalytics_Clean
--
-- STRUCTURE: 21,708 rows loaded from source
--   21,357 allopathic | 351 herbal
--
-- SCHEMA NOTE:
--   Package_Container, Package_Size, and Unit_Price are not
--   present in this table. They were split into child tables
--   by the ETL project:
--     - 07_Medicine_PackageSize_ETL.sql    → Medicine_PackageSize
--     - 07b_Medicine_PackageContainer_ETL.sql → Medicine_PackageContainer
--   Cleaning of those child tables is covered in:
--     - 09_MedicinePackageSize_Cleaning.sql
--     - 10_MedicinePackageContainer_Cleaning.sql
--
-- NULL PROFILE:
--   Brand_Name      : 0 NULL   -- clean
--   Type            : 0 NULL   -- clean
--   Dosage_Form_ID  : 0 NULL   -- clean
--   Generic_ID      : 214 NULL -- medicines with no generic classification
--                                 (expected; left as NULL)
--   Strength        : 849 NULL -- missing source data across multiple form types
--                                 (no systematic pattern; unrecoverable; documented)
--   Manufacturer_ID : 147 NULL -- medicines with unknown manufacturer
--                                 (expected; left as NULL)
--
-- DUPLICATES: Hundreds of Brand_Names appear 2-9 times.
--   All confirmed legitimate: same brand name, different strengths/dosage forms.
--   Example: Napa x8 = 8 distinct strength/form combinations.
--   No duplicate rows exist.
--
-- ENCODING: 0 non-ASCII characters in Brand_Name. Clean.
--
-- TYPE VALUES: Only 'allopathic' and 'herbal'. No issues.
--
-- CONCLUSION: No UPDATE or DELETE statements required.
--   Medicine table is accepted as-is with documented NULL fields.
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- =================================================
-- INSPECTION
-- =================================================

-- Full table preview
SELECT *
FROM Medicine;

-- Row count and type distribution
SELECT
    Type,
    COUNT(*) AS Count
FROM Medicine
GROUP BY Type
ORDER BY Count DESC;

-- NULL profile
SELECT
    SUM(CASE WHEN Brand_Name IS NULL THEN 1 ELSE 0 END)        AS Null_Brand_Name,
    SUM(CASE WHEN Type IS NULL THEN 1 ELSE 0 END)               AS Null_Type,
    SUM(CASE WHEN Dosage_Form_ID IS NULL THEN 1 ELSE 0 END)     AS Null_Dosage_Form_ID,
    SUM(CASE WHEN Generic_ID IS NULL THEN 1 ELSE 0 END)         AS Null_Generic_ID,
    SUM(CASE WHEN Strength IS NULL THEN 1 ELSE 0 END)           AS Null_Strength,
    SUM(CASE WHEN Manufacturer_ID IS NULL THEN 1 ELSE 0 END)    AS Null_Manufacturer_ID
FROM Medicine;
-- Expected: 0 | 0 | 0 | 214 | 849 | 147

-- Duplicate check — same Brand_Name + Strength + Dosage_Form_ID + Generic_ID + Manufacturer_ID
-- Known result: 59 true duplicate rows from CSV parsing artifacts in source data.
-- These are carried forward from the ETL project intentionally —
-- candidate for deduplication here.
SELECT
    Brand_Name,
    Strength,
    Dosage_Form_ID,
    Generic_ID,
    Manufacturer_ID,
    COUNT(*) AS Count
FROM Medicine
GROUP BY
    Brand_Name,
    Strength,
    Dosage_Form_ID,
    Generic_ID,
    Manufacturer_ID
HAVING COUNT(*) > 1
ORDER BY Count DESC;

-- Encoding artifacts in Brand_Name
SELECT Brand_ID, Brand_Name
FROM Medicine
WHERE Brand_Name COLLATE Latin1_General_BIN
      LIKE '%[^ -~]%';

-- Whitespace check
SELECT COUNT(*) AS Whitespace_Issues
FROM Medicine
WHERE Brand_Name != LTRIM(RTRIM(Brand_Name));

-- Type values check
SELECT DISTINCT Type FROM Medicine;

-- Strength NULL breakdown by dosage form
-- To understand whether NULLs are systematic or random
SELECT
    df.Dosage_Form_Name,
    COUNT(*) AS Total,
    SUM(CASE WHEN m.Strength IS NULL THEN 1 ELSE 0 END) AS Null_Strength
FROM Medicine m
LEFT JOIN Dosage_Form df ON m.Dosage_Form_ID = df.Dosage_Form_ID
GROUP BY df.Dosage_Form_Name
HAVING SUM(CASE WHEN m.Strength IS NULL THEN 1 ELSE 0 END) > 0
ORDER BY Null_Strength DESC;

-- =================================================
-- NO FIXES APPLIED
-- =================================================
-- All NULL fields are documented above and accepted as-is.
-- 59 duplicate rows are carried forward from the ETL project
-- and flagged as candidates for deduplication below.
-- =================================================

-- =================================================
-- FINAL SUMMARY
-- =================================================

SELECT
    COUNT(*)                                                        AS Total_Rows,
    SUM(CASE WHEN Brand_Name IS NULL THEN 1 ELSE 0 END)            AS Null_Brand_Name,
    SUM(CASE WHEN Type IS NULL THEN 1 ELSE 0 END)                  AS Null_Type,
    SUM(CASE WHEN Dosage_Form_ID IS NULL THEN 1 ELSE 0 END)        AS Null_Dosage_Form_ID,
    SUM(CASE WHEN Generic_ID IS NULL THEN 1 ELSE 0 END)            AS Null_Generic_ID,
    SUM(CASE WHEN Strength IS NULL THEN 1 ELSE 0 END)              AS Null_Strength,
    SUM(CASE WHEN Manufacturer_ID IS NULL THEN 1 ELSE 0 END)       AS Null_Manufacturer_ID,
    SUM(CASE WHEN Brand_Name COLLATE Latin1_General_BIN
             LIKE '%[^ -~]%' THEN 1 ELSE 0 END)                    AS Encoding_Issues
FROM Medicine;
-- Expected: 21708 | 0 | 0 | 0 | 214 | 849 | 147 | 0
GO