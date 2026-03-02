-- =================================================
-- 12_Validation.sql
-- Final validation checks for PharmaMarketAnalytics_Clean
-- Run this script AFTER all cleaning scripts (03 through 11)
--
-- Expected results summary:
--   Section 1  — row counts match expected post-cleaning values
--   Section 2  — all issue counts = 0 (or match documented exceptions)
--   Section 3  — all referential integrity counts = 0
--   Section 4  — all encoding counts = 0 (or match documented exceptions)
--   Section 5  — review manually for sense-checking
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- =================================================
-- SECTION 1: ROW COUNTS
-- Confirms all tables have the expected number of rows
-- after cleaning scripts have run.
-- =================================================

SELECT 'Drug_Class'                AS TableName, COUNT(*) AS [RowCount] FROM Drug_Class
UNION ALL
SELECT 'Dosage_Form',                              COUNT(*) FROM Dosage_Form
UNION ALL
SELECT 'Manufacturer',                             COUNT(*) FROM Manufacturer
UNION ALL
SELECT 'Indication',                               COUNT(*) FROM Indication
UNION ALL
SELECT 'Generic',                                  COUNT(*) FROM Generic
UNION ALL
SELECT 'Medicine',                                 COUNT(*) FROM Medicine
UNION ALL
SELECT 'Medicine_PackageSize',                     COUNT(*) FROM Medicine_PackageSize
UNION ALL
SELECT 'Medicine_PackageContainer',                COUNT(*) FROM Medicine_PackageContainer
UNION ALL
SELECT 'Generic_Indication',                       COUNT(*) FROM Generic_Indication
ORDER BY TableName;
-- Expected:
--   Drug_Class              : 422  (reduced from 1,599 — comma rows deleted, duplicates removed)
--   Dosage_Form             : 113  (unchanged)
--   Generic                 : 1711 (unchanged)
--   Generic_Indication      : 1608 (unchanged)
--   Indication              : 2043 (unchanged)
--   Manufacturer            : 240  (unchanged)
--   Medicine                : 21708 (unchanged)
--   Medicine_PackageContainer: 22707 (unchanged)
--   Medicine_PackageSize    : 14349 (unchanged)
GO

-- =================================================
-- SECTION 2: DATA QUALITY CHECKS
-- One query per table covering all known issue types.
-- All counts should be 0 unless documented otherwise.
-- =================================================

-- -------------------------------------------------
-- Drug_Class
-- -------------------------------------------------
SELECT
    COUNT(*)                                                          AS Total_Rows,
    SUM(CASE WHEN Drug_Class_Name = 'N/A' THEN 1 ELSE 0 END)         AS NA_Placeholder,
    -- Note: 1 expected — placeholder for unrecoverable lone/leading comma rows
    SUM(CASE WHEN Drug_Class_Name LIKE '%,%' THEN 1 ELSE 0 END)       AS Remaining_Comma_Issues,
    SUM(CASE WHEN Drug_Class_Name COLLATE Latin1_General_BIN
             LIKE '%[^ -~]%' THEN 1 ELSE 0 END)                       AS Non_ASCII_Characters,
    -- Note: 2 expected — Drug_Class_IDs 239 and 362 contain intentional β (NCHAR 946)
    (SELECT COUNT(*) FROM (
        SELECT Drug_Class_Name FROM Drug_Class
        GROUP BY Drug_Class_Name HAVING COUNT(*) > 1
     ) d)                                                              AS Duplicate_Names
FROM Drug_Class;
-- Expected: 422 | 1 | 0 | 2 | 0

-- -------------------------------------------------
-- Dosage_Form
-- -------------------------------------------------
SELECT
    COUNT(*)                                                          AS Total_Rows,
    SUM(CASE WHEN Dosage_Form_Name IS NULL THEN 1 ELSE 0 END)         AS Null_Names,
    SUM(CASE WHEN LTRIM(RTRIM(Dosage_Form_Name)) = ''
             THEN 1 ELSE 0 END)                                        AS Blank_Names,
    SUM(CASE WHEN Dosage_Form_Name LIKE '%,%' THEN 1 ELSE 0 END)      AS Comma_Issues,
    SUM(CASE WHEN Dosage_Form_Name COLLATE Latin1_General_BIN
             LIKE '%[^ -~]%' THEN 1 ELSE 0 END)                       AS Encoding_Issues,
    (SELECT COUNT(*) FROM (
        SELECT Dosage_Form_Name FROM Dosage_Form
        GROUP BY Dosage_Form_Name HAVING COUNT(*) > 1
     ) d)                                                              AS Duplicate_Names
FROM Dosage_Form;
-- Expected: 113 | 0 | 0 | 0 | 0 | 0

-- -------------------------------------------------
-- Manufacturer
-- -------------------------------------------------
SELECT
    COUNT(*)                                                           AS Total_Rows,
    SUM(CASE WHEN Manufacturer_Name IS NULL THEN 1 ELSE 0 END)        AS Null_Names,
    SUM(CASE WHEN LTRIM(RTRIM(Manufacturer_Name)) = ''
             THEN 1 ELSE 0 END)                                        AS Blank_Names,
    SUM(CASE WHEN Manufacturer_Name LIKE '%  %' THEN 1 ELSE 0 END)    AS Double_Spaces,
    SUM(CASE WHEN Manufacturer_Name COLLATE Latin1_General_BIN
             LIKE '%[^ -~]%' THEN 1 ELSE 0 END)                       AS Encoding_Issues,
    SUM(CASE WHEN Manufacturer_Name LIKE '%Ltd'
             COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END)          AS Ltd_Without_Period,
    SUM(CASE WHEN Manufacturer_Name LIKE '%ltd.'
             COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END)          AS Lowercase_Ltd,
    (SELECT COUNT(*) FROM (
        SELECT Manufacturer_Name FROM Manufacturer
        GROUP BY Manufacturer_Name HAVING COUNT(*) > 1
     ) d)                                                              AS Duplicate_Names
FROM Manufacturer;
-- Expected: 240 | 0 | 0 | 0 | 0 | 0 | 0 | 0

-- -------------------------------------------------
-- Indication
-- -------------------------------------------------
SELECT
    COUNT(*)                                                          AS Total_Rows,
    SUM(CASE WHEN Indication_Name IS NULL THEN 1 ELSE 0 END)          AS Null_Names,
    SUM(CASE WHEN LTRIM(RTRIM(Indication_Name)) = ''
             THEN 1 ELSE 0 END)                                        AS Blank_Names,
    SUM(CASE WHEN Indication_Name LIKE
             '%' + NCHAR(226) + NCHAR(8364) + NCHAR(8482) + '%'
             THEN 1 ELSE 0 END)                                        AS Garbled_Apostrophes,
    SUM(CASE WHEN Indication_Name LIKE '%' + NCHAR(194) + '%'
             THEN 1 ELSE 0 END)                                        AS Garbled_NBSP,
    SUM(CASE WHEN Indication_Name LIKE
             '%' + NCHAR(195) + NCHAR(182) + '%'
             THEN 1 ELSE 0 END)                                        AS Garbled_Umlaut,
    (SELECT COUNT(*) FROM (
        SELECT Indication_Name FROM Indication
        GROUP BY Indication_Name HAVING COUNT(*) > 1
     ) d)                                                              AS Duplicate_Names
FROM Indication;
-- Expected: 2043 | 0 | 0 | 0 | 0 | 0 | 0

-- -------------------------------------------------
-- Generic
-- -------------------------------------------------
SELECT
    COUNT(*)                                                              AS Total_Rows,
    SUM(CASE WHEN Generic_Name IS NULL THEN 1 ELSE 0 END)                AS Null_Names,
    SUM(CASE WHEN LTRIM(RTRIM(Generic_Name)) = ''
             THEN 1 ELSE 0 END)                                           AS Blank_Names,
    SUM(CASE WHEN Generic_Name LIKE
             '%' + NCHAR(226) + NCHAR(8364) + NCHAR(8482) + '%'
             THEN 1 ELSE 0 END)                                           AS Garbled_Apostrophes,
    SUM(CASE WHEN Generic_Name LIKE
             '%' + NCHAR(194) + '+' + NCHAR(194) + '%'
             THEN 1 ELSE 0 END)                                           AS Garbled_NBSP_Plus,
    SUM(CASE WHEN Generic_Name LIKE '%' + NCHAR(194) + '%'
             THEN 1 ELSE 0 END)                                           AS Garbled_NBSP,
    SUM(CASE WHEN Generic_Name LIKE
             '%' + NCHAR(206) + NCHAR(178) + '%'
             THEN 1 ELSE 0 END)                                           AS Garbled_Beta,
    SUM(CASE WHEN Drug_Class_ID = 0 THEN 1 ELSE 0 END)                   AS NA_Drug_Class,
    -- Note: 61 expected — unresolvable drug class from source data
    (SELECT COUNT(*) FROM (
        SELECT Generic_Name FROM Generic
        GROUP BY Generic_Name HAVING COUNT(*) > 1
     ) d)                                                                  AS Duplicate_Names
FROM Generic;
-- Expected: 1711 | 0 | 0 | 0 | 0 | 0 | 0 | 61 | 0

-- -------------------------------------------------
-- Medicine
-- -------------------------------------------------
SELECT
    COUNT(*)                                                        AS Total_Rows,
    SUM(CASE WHEN Brand_Name IS NULL THEN 1 ELSE 0 END)            AS Null_Brand_Name,
    SUM(CASE WHEN Type IS NULL THEN 1 ELSE 0 END)                  AS Null_Type,
    SUM(CASE WHEN Dosage_Form_ID IS NULL THEN 1 ELSE 0 END)        AS Null_Dosage_Form_ID,
    SUM(CASE WHEN Generic_ID IS NULL THEN 1 ELSE 0 END)            AS Null_Generic_ID,
    -- Note: 214 expected — medicines with no generic classification
    SUM(CASE WHEN Strength IS NULL THEN 1 ELSE 0 END)              AS Null_Strength,
    -- Note: 849 expected — missing source data, unrecoverable
    SUM(CASE WHEN Manufacturer_ID IS NULL THEN 1 ELSE 0 END)       AS Null_Manufacturer_ID,
    -- Note: 147 expected — medicines with unknown manufacturer
    SUM(CASE WHEN Brand_Name COLLATE Latin1_General_BIN
             LIKE '%[^ -~]%' THEN 1 ELSE 0 END)                    AS Encoding_Issues
FROM Medicine;
-- Expected: 21708 | 0 | 0 | 0 | 214 | 849 | 147 | 0

-- -------------------------------------------------
-- Medicine_PackageSize
-- -------------------------------------------------
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
    -- Note: 1 expected — Unisaline Fruity upstream artifact
FROM Medicine_PackageSize;
-- Expected: 14349 | 0 | 0 | 0 | 1

-- -------------------------------------------------
-- Medicine_PackageContainer
-- -------------------------------------------------
SELECT
    COUNT(*)                                                                    AS Total_Rows,
    SUM(CASE WHEN Container_Size IS NULL THEN 1 ELSE 0 END)                    AS Null_Container_Size,
    -- Note: 13496 expected — Format B unit-priced medicines
    SUM(CASE WHEN Unit_Price     IS NULL THEN 1 ELSE 0 END)                    AS Null_Unit_Price,
    -- Note: 39 expected — placeholder rows (Price Unavailable / Not for sale)
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

-- -------------------------------------------------
-- Generic_Indication
-- -------------------------------------------------
SELECT
    COUNT(*)                                                         AS Total_Rows,
    SUM(CASE WHEN Generic_ID IS NULL THEN 1 ELSE 0 END)             AS Null_Generic_ID,
    SUM(CASE WHEN Indication_ID IS NULL THEN 1 ELSE 0 END)          AS Null_Indication_ID,
    COUNT(DISTINCT Generic_ID)                                       AS Distinct_Generics,
    COUNT(DISTINCT Indication_ID)                                    AS Distinct_Indications,
    (SELECT COUNT(*) FROM (
        SELECT Generic_ID, Indication_ID FROM Generic_Indication
        GROUP BY Generic_ID, Indication_ID HAVING COUNT(*) > 1
     ) d)                                                            AS Duplicate_Pairs
FROM Generic_Indication;
-- Expected: 1608 | 0 | 0 | 1608 | 662 | 0
GO

-- =================================================
-- SECTION 3: REFERENTIAL INTEGRITY CHECKS
-- All counts should be 0.
-- =================================================

SELECT 'Generic -> Drug_Class broken FK' AS Check_Name,
       COUNT(*) AS IssueCount
FROM Generic g
LEFT JOIN Drug_Class dc ON g.Drug_Class_ID = dc.Drug_Class_ID
WHERE dc.Drug_Class_ID IS NULL;

SELECT 'Medicine -> Dosage_Form broken FK' AS Check_Name,
       COUNT(*) AS IssueCount
FROM Medicine m
LEFT JOIN Dosage_Form df ON m.Dosage_Form_ID = df.Dosage_Form_ID
WHERE m.Dosage_Form_ID IS NOT NULL AND df.Dosage_Form_ID IS NULL;

SELECT 'Medicine -> Generic broken FK' AS Check_Name,
       COUNT(*) AS IssueCount
FROM Medicine m
LEFT JOIN Generic g ON m.Generic_ID = g.Generic_ID
WHERE m.Generic_ID IS NOT NULL AND g.Generic_ID IS NULL;

SELECT 'Medicine -> Manufacturer broken FK' AS Check_Name,
       COUNT(*) AS IssueCount
FROM Medicine m
LEFT JOIN Manufacturer mf ON m.Manufacturer_ID = mf.Manufacturer_ID
WHERE m.Manufacturer_ID IS NOT NULL AND mf.Manufacturer_ID IS NULL;

SELECT 'Medicine_PackageSize -> Medicine broken FK' AS Check_Name,
       COUNT(*) AS IssueCount
FROM Medicine_PackageSize ps
LEFT JOIN Medicine m ON ps.Brand_ID = m.Brand_ID
WHERE m.Brand_ID IS NULL;

SELECT 'Medicine_PackageContainer -> Medicine broken FK' AS Check_Name,
       COUNT(*) AS IssueCount
FROM Medicine_PackageContainer pc
LEFT JOIN Medicine m ON pc.Brand_ID = m.Brand_ID
WHERE m.Brand_ID IS NULL;

SELECT 'Generic_Indication -> Generic broken FK' AS Check_Name,
       COUNT(*) AS IssueCount
FROM Generic_Indication gi
LEFT JOIN Generic g ON gi.Generic_ID = g.Generic_ID
WHERE g.Generic_ID IS NULL;

SELECT 'Generic_Indication -> Indication broken FK' AS Check_Name,
       COUNT(*) AS IssueCount
FROM Generic_Indication gi
LEFT JOIN Indication i ON gi.Indication_ID = i.Indication_ID
WHERE i.Indication_ID IS NULL;
GO

-- =================================================
-- SECTION 4: ENCODING CHECKS
-- =================================================

-- Drug_Class: 2 expected — intentional β (NCHAR 946) in IDs 239 and 362
SELECT 'Drug_Class — non-ASCII characters' AS Check_Name,
       COUNT(*) AS Count
FROM Drug_Class
WHERE Drug_Class_Name COLLATE Latin1_General_BIN LIKE '%[^ -~]%';

-- Dosage_Form: 0 expected
SELECT 'Dosage_Form — non-ASCII characters' AS Check_Name,
       COUNT(*) AS Count
FROM Dosage_Form
WHERE Dosage_Form_Name COLLATE Latin1_General_BIN LIKE '%[^ -~]%';

-- Manufacturer: 1 expected — ID 65 'Doctor's Chemical Works Ltd.' contains
-- intentional curly apostrophe NCHAR(8217) after encoding fix
SELECT 'Manufacturer — non-ASCII characters (1 intentional Unicode expected)' AS Check_Name,
       COUNT(*) AS Count
FROM Manufacturer
WHERE Manufacturer_Name COLLATE Latin1_General_BIN LIKE '%[^ -~]%';

-- Indication: 23 expected — 22 intentional curly apostrophes (NCHAR 8217)
-- and 1 intentional umlaut ö (NCHAR 246) remain after cleaning
SELECT 'Indication — non-ASCII characters (23 intentional Unicode expected)' AS Check_Name,
       COUNT(*) AS Count
FROM Indication
WHERE Indication_Name COLLATE Latin1_General_BIN LIKE '%[^ -~]%';

-- Generic: 3 expected — 2 intentional curly apostrophes (NCHAR 8217)
-- and 1 intentional β (NCHAR 946) remain after cleaning
SELECT 'Generic — non-ASCII characters (3 intentional Unicode expected)' AS Check_Name,
       COUNT(*) AS Count
FROM Generic
WHERE Generic_Name COLLATE Latin1_General_BIN LIKE '%[^ -~]%';

-- Medicine: 0 expected
SELECT 'Medicine — non-ASCII characters in Brand_Name' AS Check_Name,
       COUNT(*) AS Count
FROM Medicine
WHERE Brand_Name COLLATE Latin1_General_BIN LIKE '%[^ -~]%';

-- Medicine_PackageContainer: 0 expected — µg standardised to mcg by ETL
SELECT 'Medicine_PackageContainer — non-ASCII characters in Container_Size' AS Check_Name,
       COUNT(*) AS Count
FROM Medicine_PackageContainer
WHERE Container_Size COLLATE Latin1_General_BIN LIKE '%[^ -~]%';
GO

-- =================================================
-- SECTION 5: SAMPLE DATA PREVIEWS
-- Visual spot-check — review these rows manually.
-- =================================================

SELECT TOP 5 * FROM Drug_Class              ORDER BY Drug_Class_ID;
SELECT TOP 5 * FROM Dosage_Form             ORDER BY Dosage_Form_ID;
SELECT TOP 5 * FROM Manufacturer            ORDER BY Manufacturer_ID;
SELECT TOP 5 * FROM Indication              ORDER BY Indication_ID;
SELECT TOP 5 * FROM Generic                 ORDER BY Generic_ID;
SELECT TOP 5 * FROM Medicine                ORDER BY Brand_ID;
SELECT TOP 5 * FROM Medicine_PackageSize    ORDER BY PackageSize_ID;
SELECT TOP 5 * FROM Medicine_PackageContainer ORDER BY PackageContainer_ID;
SELECT TOP 5 * FROM Generic_Indication      ORDER BY Generic_Indication_ID;
GO

-- =================================================
-- END OF VALIDATION SCRIPT
-- =================================================
