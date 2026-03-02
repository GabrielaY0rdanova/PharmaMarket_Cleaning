-- =================================================
-- 03_DrugClass_Cleaning.sql
-- Cleans the Drug_Class table in PharmaMarketAnalytics_Clean
--
-- Issues found during inspection:
--   1. 1 lone comma row (Drug_Class_Name = ',')
--   2. 10 leading comma rows (Drug_Class_Name LIKE ',%')
--   3. 24 trailing comma rows (Drug_Class_Name LIKE '%,')
--   4. 1143 both-parts rows (Drug_Class_Name contains embedded indication)
--   5. 2 encoding artifacts in surviving rows (garbled beta symbol Î²)
--
-- Decisions:
--   - Lone and leading comma rows: drug class name unrecoverable
--     Affected generics reassigned to placeholder Drug_Class_ID = 0 (N/A)
--     Drug_Class rows deleted
--   - Trailing comma rows: strip trailing comma, keep the row
--     Note: all 24 became duplicates after stripping — handled in Fix 2b
--   - Both-parts rows: reassign linked generics to existing clean row
--     then delete duplicates
--   - Encoding artifacts: fixed after comma cleanup (only 2 rows survive)
--
-- Not fixed:
--   - & vs and: intentional distinction in source data
--   - / spacing: minor inconsistency, low priority
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- =================================================
-- INSPECTION
-- =================================================

-- Full table preview
SELECT *
FROM Drug_Class;

-- All distinct drug class names
SELECT DISTINCT Drug_Class_Name
FROM Drug_Class
ORDER BY Drug_Class_Name;

-- Non-ASCII characters (encoding artifacts)
SELECT Drug_Class_ID, Drug_Class_Name
FROM Drug_Class
WHERE Drug_Class_Name COLLATE Latin1_General_BIN
      LIKE '%[^ -~]%';

-- Count each issue type
SELECT
    SUM(CASE WHEN Drug_Class_Name LIKE ',%'
             AND Drug_Class_Name <> ',' THEN 1 ELSE 0 END)        AS Leading_Comma,
    SUM(CASE WHEN Drug_Class_Name = ',' THEN 1 ELSE 0 END)         AS Lone_Comma,
    SUM(CASE WHEN Drug_Class_Name LIKE '%,'
             AND Drug_Class_Name NOT LIKE ',%' THEN 1 ELSE 0 END)  AS Trailing_Comma,
    SUM(CASE WHEN Drug_Class_Name LIKE '%,%'
             AND Drug_Class_Name NOT LIKE ',%'
             AND Drug_Class_Name NOT LIKE '%,' THEN 1 ELSE 0 END)  AS Both_Parts,
    SUM(CASE WHEN Drug_Class_Name COLLATE Latin1_General_BIN
             LIKE '%[^ -~]%' THEN 1 ELSE 0 END)                    AS Encoding_Issues
FROM Drug_Class;

-- Generics linked to lone/leading comma rows
SELECT
    g.Generic_ID,
    g.Generic_Name,
    g.Drug_Class_ID,
    dc.Drug_Class_Name
FROM Generic g
INNER JOIN Drug_Class dc ON g.Drug_Class_ID = dc.Drug_Class_ID
WHERE dc.Drug_Class_Name = ','
   OR dc.Drug_Class_Name LIKE ',%'
ORDER BY dc.Drug_Class_Name, g.Generic_Name;

-- =================================================
-- FIX 1: LONE AND LEADING COMMA ROWS
-- Drug class name is unrecoverable for these rows.
-- Affected generics reassigned to placeholder Drug_Class_ID = 0 (N/A)
-- Drug_Class rows then deleted.
-- =================================================

-- Insert N/A placeholder
INSERT INTO Drug_Class (Drug_Class_ID, Drug_Class_Name, Slug)
VALUES (0, 'N/A', 'n-a');

-- Preview generics to be reassigned
SELECT
    g.Generic_ID,
    g.Generic_Name,
    g.Drug_Class_ID,
    dc.Drug_Class_Name
FROM Generic g
INNER JOIN Drug_Class dc ON g.Drug_Class_ID = dc.Drug_Class_ID
WHERE dc.Drug_Class_Name = ','
   OR dc.Drug_Class_Name LIKE ',%'
ORDER BY dc.Drug_Class_Name, g.Generic_Name;

-- Reassign generics to Drug_Class_ID = 0
UPDATE Generic
SET Drug_Class_ID = 0
WHERE Drug_Class_ID IN (
    SELECT Drug_Class_ID
    FROM Drug_Class
    WHERE Drug_Class_Name = ','
       OR Drug_Class_Name LIKE ',%'
);

-- Preview Drug_Class rows to be deleted
SELECT Drug_Class_ID, Drug_Class_Name
FROM Drug_Class
WHERE Drug_Class_Name = ','
   OR Drug_Class_Name LIKE ',%';

-- Delete lone and leading comma rows
DELETE FROM Drug_Class
WHERE Drug_Class_Name = ','
   OR Drug_Class_Name LIKE ',%';

-- ==========================
-- VERIFY FIX 1
-- ==========================

-- Confirm lone/leading comma rows are gone
SELECT
    COUNT(*) AS Drug_Class_Count,
    SUM(CASE WHEN Drug_Class_Name = ','
             OR Drug_Class_Name LIKE ',%' THEN 1 ELSE 0 END) AS Remaining_Issues
FROM Drug_Class;

-- Confirm generics were reassigned
SELECT COUNT(*) AS Generics_With_NA
FROM Generic
WHERE Drug_Class_ID = 0;

-- Check for unintended side effects — any new duplicates?
SELECT Drug_Class_Name, COUNT(*) AS Count
FROM Drug_Class
GROUP BY Drug_Class_Name
HAVING COUNT(*) > 1
ORDER BY Drug_Class_Name;

-- =================================================
-- FIX 2: TRAILING COMMA ROWS
-- Strip the trailing comma from Drug_Class_Name.
-- No generics need reassigning — rows are kept.
-- Note: stripping may create duplicates if a clean version
--       of the name already exists — checked in VERIFY below.
-- =================================================

-- Preview trailing comma rows
SELECT
    Drug_Class_ID,
    Drug_Class_Name,
    TRIM(',' FROM Drug_Class_Name) AS Stripped_Name
FROM Drug_Class
WHERE Drug_Class_Name LIKE '%,';

-- Strip trailing comma
UPDATE Drug_Class
SET Drug_Class_Name = TRIM(',' FROM Drug_Class_Name)
WHERE Drug_Class_Name LIKE '%,';

-- ==========================
-- VERIFY FIX 2
-- ==========================

-- Confirm trailing commas are gone
SELECT COUNT(*) AS Remaining_Trailing_Commas
FROM Drug_Class
WHERE Drug_Class_Name LIKE '%,';

-- Check for unintended side effects — did Fix 2 create duplicates?
-- If this returns rows, handle them in Fix 2b
SELECT Drug_Class_Name, COUNT(*) AS Count
FROM Drug_Class
GROUP BY Drug_Class_Name
HAVING COUNT(*) > 1
ORDER BY Drug_Class_Name;

-- =================================================
-- FIX 2b: TRAILING COMMA DUPLICATES
-- Fix 2 created duplicates — stripping the trailing comma
-- produced names that already existed as clean rows.
-- The CTE below identifies which rows to keep (lower ID = original)
-- and which to delete (higher ID = former trailing comma row).
-- =================================================

-- Identify duplicate pairs created by Fix 2
WITH Duplicates AS (
    SELECT
        Drug_Class_Name,
        MIN(Drug_Class_ID) AS Keep_ID,
        MAX(Drug_Class_ID) AS Delete_ID
    FROM Drug_Class
    GROUP BY Drug_Class_Name
    HAVING COUNT(*) > 1
)
SELECT * FROM Duplicates
ORDER BY Drug_Class_Name;

-- Preview generics linked to duplicate rows
WITH Duplicates AS (
    SELECT
        MIN(Drug_Class_ID) AS Keep_ID,
        MAX(Drug_Class_ID) AS Delete_ID
    FROM Drug_Class
    GROUP BY Drug_Class_Name
    HAVING COUNT(*) > 1
)
SELECT
    g.Generic_ID,
    g.Generic_Name,
    g.Drug_Class_ID         AS Current_ID,
    keep_dc.Drug_Class_ID   AS New_ID,
    keep_dc.Drug_Class_Name AS New_Name
FROM Generic g
INNER JOIN Drug_Class delete_dc ON g.Drug_Class_ID = delete_dc.Drug_Class_ID
INNER JOIN Duplicates d         ON delete_dc.Drug_Class_ID = d.Delete_ID
INNER JOIN Drug_Class keep_dc   ON keep_dc.Drug_Class_ID = d.Keep_ID;

-- Reassign generics to the original clean row
WITH Duplicates AS (
    SELECT
        MIN(Drug_Class_ID) AS Keep_ID,
        MAX(Drug_Class_ID) AS Delete_ID
    FROM Drug_Class
    GROUP BY Drug_Class_Name
    HAVING COUNT(*) > 1
)
UPDATE g
SET g.Drug_Class_ID = d.Keep_ID
FROM Generic g
INNER JOIN Duplicates d ON g.Drug_Class_ID = d.Delete_ID;

-- Preview duplicate rows to be deleted
WITH Duplicates AS (
    SELECT
        MIN(Drug_Class_ID) AS Keep_ID,
        MAX(Drug_Class_ID) AS Delete_ID
    FROM Drug_Class
    GROUP BY Drug_Class_Name
    HAVING COUNT(*) > 1
)
SELECT dc.Drug_Class_ID, dc.Drug_Class_Name
FROM Drug_Class dc
INNER JOIN Duplicates d ON dc.Drug_Class_ID = d.Delete_ID;

-- Delete duplicate rows
WITH Duplicates AS (
    SELECT
        MIN(Drug_Class_ID) AS Keep_ID,
        MAX(Drug_Class_ID) AS Delete_ID
    FROM Drug_Class
    GROUP BY Drug_Class_Name
    HAVING COUNT(*) > 1
)
DELETE dc
FROM Drug_Class dc
INNER JOIN Duplicates d ON dc.Drug_Class_ID = d.Delete_ID;

-- ==========================
-- VERIFY FIX 2b
-- ==========================

-- Confirm no duplicates remain
SELECT COUNT(*) AS Remaining_Duplicates
FROM (
    SELECT Drug_Class_Name
    FROM Drug_Class
    GROUP BY Drug_Class_Name
    HAVING COUNT(*) > 1
) d;

-- Row count after Fix 2b
SELECT COUNT(*) AS Drug_Class_Count FROM Drug_Class;

-- Check for unintended side effects — any orphaned generics?
SELECT COUNT(*) AS Orphaned_Generics
FROM Generic g
LEFT JOIN Drug_Class dc ON g.Drug_Class_ID = dc.Drug_Class_ID
WHERE dc.Drug_Class_ID IS NULL;

-- =================================================
-- FIX 3: BOTH-PARTS ROWS
-- 1143 rows contain embedded indication data after a comma
-- e.g. '4-Quinolone preparations,Acute bacterial sinusitis'
-- Extract the drug class name (part before the comma),
-- reassign linked generics to the existing clean row,
-- then delete the duplicate rows.
-- =================================================

-- Preview reassignments
SELECT
    dc.Drug_Class_ID                                                    AS Current_ID,
    dc.Drug_Class_Name                                                  AS Current_Name,
    LEFT(dc.Drug_Class_Name, CHARINDEX(',', dc.Drug_Class_Name) - 1)   AS Extracted_Name,
    clean.Drug_Class_ID                                                 AS Target_ID,
    clean.Drug_Class_Name                                               AS Target_Name
FROM Drug_Class dc
INNER JOIN Drug_Class clean
    ON clean.Drug_Class_Name = LEFT(dc.Drug_Class_Name, CHARINDEX(',', dc.Drug_Class_Name) - 1)
WHERE dc.Drug_Class_Name LIKE '%,%'
  AND dc.Drug_Class_Name NOT LIKE ',%'
  AND dc.Drug_Class_Name NOT LIKE '%,';

-- Preview generics to be reassigned
SELECT
    g.Generic_ID,
    g.Generic_Name,
    g.Drug_Class_ID            AS Current_ID,
    dc.Drug_Class_Name         AS Current_Name,
    clean.Drug_Class_ID        AS New_ID,
    clean.Drug_Class_Name      AS New_Name
FROM Generic g
INNER JOIN Drug_Class dc
    ON g.Drug_Class_ID = dc.Drug_Class_ID
INNER JOIN Drug_Class clean
    ON clean.Drug_Class_Name = LEFT(dc.Drug_Class_Name, CHARINDEX(',', dc.Drug_Class_Name) - 1)
WHERE dc.Drug_Class_Name LIKE '%,%'
  AND dc.Drug_Class_Name NOT LIKE ',%'
  AND dc.Drug_Class_Name NOT LIKE '%,';

-- Reassign generics to the clean Drug_Class_ID
UPDATE g
SET g.Drug_Class_ID = clean.Drug_Class_ID
FROM Generic g
INNER JOIN Drug_Class dc
    ON g.Drug_Class_ID = dc.Drug_Class_ID
INNER JOIN Drug_Class clean
    ON clean.Drug_Class_Name = LEFT(dc.Drug_Class_Name, CHARINDEX(',', dc.Drug_Class_Name) - 1)
WHERE dc.Drug_Class_Name LIKE '%,%'
  AND dc.Drug_Class_Name NOT LIKE ',%'
  AND dc.Drug_Class_Name NOT LIKE '%,';

-- Preview both-parts rows to be deleted
SELECT Drug_Class_ID, Drug_Class_Name
FROM Drug_Class
WHERE Drug_Class_Name LIKE '%,%'
  AND Drug_Class_Name NOT LIKE ',%'
  AND Drug_Class_Name NOT LIKE '%,';

-- Delete both-parts rows
DELETE FROM Drug_Class
WHERE Drug_Class_Name LIKE '%,%'
  AND Drug_Class_Name NOT LIKE ',%'
  AND Drug_Class_Name NOT LIKE '%,';

-- ==========================
-- VERIFY FIX 3
-- ==========================

-- Confirm no both-parts rows remain
SELECT COUNT(*) AS Remaining_Both_Parts
FROM Drug_Class
WHERE Drug_Class_Name LIKE '%,%'
  AND Drug_Class_Name NOT LIKE ',%'
  AND Drug_Class_Name NOT LIKE '%,';

-- Row count after Fix 3
SELECT COUNT(*) AS Drug_Class_Count FROM Drug_Class;

-- Check for unintended side effects — any orphaned generics?
SELECT COUNT(*) AS Orphaned_Generics
FROM Generic g
LEFT JOIN Drug_Class dc ON g.Drug_Class_ID = dc.Drug_Class_ID
WHERE dc.Drug_Class_ID IS NULL;

-- Check for new duplicates
SELECT Drug_Class_Name, COUNT(*) AS Count
FROM Drug_Class
GROUP BY Drug_Class_Name
HAVING COUNT(*) > 1
ORDER BY Drug_Class_Name;

-- =================================================
-- FIX 4: ENCODING ARTIFACTS
-- After comma cleanup only 2 rows have encoding issues:
--   - 'Long-acting selective Î²-adrenoceptor stimulants'
--   - 'Short-acting selective & Î²2-adrenoceptor stimulants'
-- Î² is a garbled UTF-8 representation of the Greek letter β (beta)
-- We use NCHAR(946) to guarantee the correct Unicode character
-- is inserted regardless of editor or encoding settings.
-- =================================================

-- Preview encoding issues in surviving rows
SELECT Drug_Class_ID, Drug_Class_Name,
       UNICODE(SUBSTRING(Drug_Class_Name,
           PATINDEX('%[^ -~]%' COLLATE Latin1_General_BIN, Drug_Class_Name), 1)) AS CharCode
FROM Drug_Class
WHERE Drug_Class_Name COLLATE Latin1_General_BIN
      LIKE '%[^ -~]%';

-- Fix garbled beta symbol using NCHAR(946) for correct Greek beta
UPDATE Drug_Class
SET Drug_Class_Name = REPLACE(Drug_Class_Name, NCHAR(223), NCHAR(946))
WHERE Drug_Class_ID IN (239, 362);

-- ==========================
-- VERIFY FIX 4
-- ==========================

-- Confirm the correct character was inserted (should be 946)
SELECT Drug_Class_ID, Drug_Class_Name,
       UNICODE(SUBSTRING(Drug_Class_Name,
           PATINDEX('%[^ -~]%' COLLATE Latin1_General_BIN, Drug_Class_Name), 1)) AS CharCode
FROM Drug_Class
WHERE Drug_Class_ID IN (239, 362);

-- =================================================
-- FINAL SUMMARY
-- Note: Non_ASCII_Characters = 2 is expected —
-- Drug_Class_IDs 239 and 362 contain the Greek letter β (NCHAR 946)
-- which is the correct character, not an encoding artifact.
-- =================================================
SELECT
    COUNT(*)                                                      AS Total_Rows,
    SUM(CASE WHEN Drug_Class_Name = 'N/A' THEN 1 ELSE 0 END)     AS NA_Placeholder,
    SUM(CASE WHEN Drug_Class_Name LIKE '%,%' THEN 1 ELSE 0 END)   AS Remaining_Comma_Issues,
    SUM(CASE WHEN Drug_Class_Name COLLATE Latin1_General_BIN
             LIKE '%[^ -~]%' THEN 1 ELSE 0 END)                   AS Non_ASCII_Characters
FROM Drug_Class;