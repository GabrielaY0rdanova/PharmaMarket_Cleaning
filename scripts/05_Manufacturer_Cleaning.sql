-- =================================================
-- 05_Manufacturer_Cleaning.sql
-- Cleans the Manufacturer table in PharmaMarketAnalytics_Clean
--
-- Issues found during inspection:
--   1. 1 encoding artifact: ID 65 'Doctorâ€™s Chemical Works Ltd.'
--      garbled apostrophe — should be 'Doctor's Chemical Works Ltd.'
--   2. 2 double spaces: ID 43 'Bronson  Laboratories (BD) Ltd.'
--      and ID 48 'Chemist Laboratories  Ltd.'
--   3. 3 rows with 'Ltd' missing period: IDs 7, 68, 159
--   4. 1 row with lowercase 'ltd.': ID 236
--      'West-Coast pharmaceutical works ltd.'
--   5. 1 typo: ID 129 'Libra Pharmaceuticls Ltd.'
--      missing 'a' in Pharmaceuticals
--
-- Investigated but not fixed:
--   - 'Limited' vs 'Ltd.' (13 vs 145 rows) — both are correct legal
--     suffixes. Spot-checked and confirmed each reflects the actual
--     registered company name. Standardising would reduce accuracy.
--   - Foreign language company names (e.g. 'ACM laboratoire
--     dermatologique', 'Fabrique en France') — correct in their
--     original language, not capitalisation errors.
--   - Capitalisation in trade names (e.g. 'AstraZeneca pharmaceuticals',
--     'Gulf pharmaceutical industries') — registered trade names,
--     changing them would be inaccurate.
--   - Semicolon separator in international names (e.g.
--     'Adienne Pharma; Switzerland') — consistent pattern, intentional.
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- =================================================
-- INSPECTION
-- =================================================

-- Full table preview
SELECT *
FROM Manufacturer;

-- All distinct manufacturer names
SELECT DISTINCT Manufacturer_Name
FROM Manufacturer
ORDER BY Manufacturer_Name;

-- NULL check
SELECT COUNT(*) AS Null_Names
FROM Manufacturer
WHERE Manufacturer_Name IS NULL;

-- Blank check
SELECT COUNT(*) AS Blank_Names
FROM Manufacturer
WHERE LTRIM(RTRIM(Manufacturer_Name)) = '';

-- Duplicate check
SELECT Manufacturer_Name, COUNT(*) AS Count
FROM Manufacturer
GROUP BY Manufacturer_Name
HAVING COUNT(*) > 1
ORDER BY Manufacturer_Name;

-- Encoding artifacts
SELECT Manufacturer_ID, Manufacturer_Name
FROM Manufacturer
WHERE Manufacturer_Name COLLATE Latin1_General_BIN
      LIKE '%[^ -~]%';

-- Ltd variations — case-sensitive breakdown
SELECT
    SUM(CASE WHEN Manufacturer_Name LIKE '%Ltd.'
             COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END)  AS Ltd_With_Period,
    SUM(CASE WHEN Manufacturer_Name LIKE '%Ltd'
             COLLATE Latin1_General_CS_AS
             AND Manufacturer_Name NOT LIKE '%Ltd.'
             COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END)  AS Ltd_Without_Period,
    SUM(CASE WHEN Manufacturer_Name LIKE '%Limited'
             COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END)  AS Limited,
    SUM(CASE WHEN Manufacturer_Name LIKE '%ltd.'
             COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END)  AS Lowercase_Ltd_Period,
    SUM(CASE WHEN Manufacturer_Name LIKE '% ltd'
             COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END)  AS Lowercase_Ltd_No_Period
FROM Manufacturer;

-- Show all Ltd variations
SELECT Manufacturer_ID, Manufacturer_Name,
    CASE
        WHEN Manufacturer_Name LIKE '%ltd.'
             COLLATE Latin1_General_CS_AS THEN 'lowercase ltd.'
        WHEN Manufacturer_Name LIKE '%Ltd.'
             COLLATE Latin1_General_CS_AS THEN 'Ltd.'
        WHEN Manufacturer_Name LIKE '%Ltd'
             COLLATE Latin1_General_CS_AS THEN 'Ltd'
        WHEN Manufacturer_Name LIKE '%Limited'
             COLLATE Latin1_General_CS_AS THEN 'Limited'
    END AS Variation
FROM Manufacturer
WHERE Manufacturer_Name LIKE '%Ltd%'
   OR Manufacturer_Name LIKE '%Limited%'
ORDER BY Variation, Manufacturer_Name;

-- Check for extra spaces
SELECT Manufacturer_ID, Manufacturer_Name
FROM Manufacturer
WHERE Manufacturer_Name LIKE '%  %'
   OR Manufacturer_Name LIKE ' %'
   OR Manufacturer_Name LIKE '% '
ORDER BY Manufacturer_Name;

-- Check for special characters
SELECT Manufacturer_ID, Manufacturer_Name
FROM Manufacturer
WHERE Manufacturer_Name LIKE '%(%'
   OR Manufacturer_Name LIKE '%--%'
   OR Manufacturer_Name LIKE '%/%'
ORDER BY Manufacturer_Name;

-- Names where a word after the first starts with lowercase
-- (excludes known lowercase connector words)
SELECT Manufacturer_ID, Manufacturer_Name
FROM Manufacturer
WHERE Manufacturer_Name LIKE '% [a-z]%'
  AND Manufacturer_Name NOT LIKE '% and %'
  AND Manufacturer_Name NOT LIKE '% of %'
  AND Manufacturer_Name NOT LIKE '% in %'
  AND Manufacturer_Name NOT LIKE '% for %'
  AND Manufacturer_Name NOT LIKE '% en %'
ORDER BY Manufacturer_Name;

-- =================================================
-- FIX 1: ENCODING ARTIFACT
-- 'Doctorâ€™s Chemical Works Ltd.' → 'Doctor's Chemical Works Ltd.'
-- Garbled sequence NCHAR(226)+NCHAR(8364)+NCHAR(8482) represents
-- a UTF-8 curly apostrophe — replaced with NCHAR(8217)
-- =================================================

-- Inspect character codes before fixing
SELECT
    Manufacturer_ID,
    Manufacturer_Name,
    UNICODE(SUBSTRING(Manufacturer_Name, PATINDEX('%[^ -~]%' COLLATE Latin1_General_BIN, Manufacturer_Name), 1))     AS Char1,
    UNICODE(SUBSTRING(Manufacturer_Name, PATINDEX('%[^ -~]%' COLLATE Latin1_General_BIN, Manufacturer_Name) + 1, 1)) AS Char2,
    UNICODE(SUBSTRING(Manufacturer_Name, PATINDEX('%[^ -~]%' COLLATE Latin1_General_BIN, Manufacturer_Name) + 2, 1)) AS Char3
FROM Manufacturer
WHERE Manufacturer_ID = 65;

-- Fix
UPDATE Manufacturer
SET Manufacturer_Name = REPLACE(
    Manufacturer_Name,
    NCHAR(226) + NCHAR(8364) + NCHAR(8482),
    NCHAR(8217)
)
WHERE Manufacturer_ID = 65;

-- ==========================
-- VERIFY FIX 1
-- ==========================

-- Confirm fix was applied
SELECT Manufacturer_ID, Manufacturer_Name
FROM Manufacturer
WHERE Manufacturer_ID = 65;

-- Confirm no encoding issues remain
SELECT COUNT(*) AS Remaining_Encoding_Issues
FROM Manufacturer
WHERE Manufacturer_Name COLLATE Latin1_General_BIN
      LIKE '%[^ -~]%';

-- =================================================
-- FIX 2: DOUBLE SPACES
-- ID 43 'Bronson  Laboratories (BD) Ltd.'
-- ID 48 'Chemist Laboratories  Ltd.'
-- =================================================

-- Preview
SELECT Manufacturer_ID, Manufacturer_Name,
       REPLACE(Manufacturer_Name, '  ', ' ') AS Fixed_Name
FROM Manufacturer
WHERE Manufacturer_Name LIKE '%  %';

-- Fix
UPDATE Manufacturer
SET Manufacturer_Name = REPLACE(Manufacturer_Name, '  ', ' ')
WHERE Manufacturer_Name LIKE '%  %';

-- ==========================
-- VERIFY FIX 2
-- ==========================

-- Confirm fix was applied
SELECT Manufacturer_ID, Manufacturer_Name
FROM Manufacturer
WHERE Manufacturer_ID IN (43, 48);

-- Confirm no double spaces remain
SELECT COUNT(*) AS Remaining_Double_Spaces
FROM Manufacturer
WHERE Manufacturer_Name LIKE '%  %';

-- Check for unintended side effects — any new duplicates?
SELECT Manufacturer_Name, COUNT(*) AS Count
FROM Manufacturer
GROUP BY Manufacturer_Name
HAVING COUNT(*) > 1;

-- =================================================
-- FIX 3: LTD WITHOUT PERIOD
-- IDs 7, 68, 159 — 'Ltd' → 'Ltd.'
-- =================================================

-- Preview
SELECT Manufacturer_ID, Manufacturer_Name,
       Manufacturer_Name + '.' AS Fixed_Name
FROM Manufacturer
WHERE Manufacturer_Name LIKE '%Ltd' COLLATE Latin1_General_CS_AS;

-- Fix
UPDATE Manufacturer
SET Manufacturer_Name = Manufacturer_Name + '.'
WHERE Manufacturer_Name LIKE '%Ltd' COLLATE Latin1_General_CS_AS;

-- ==========================
-- VERIFY FIX 3
-- ==========================

-- Confirm fix was applied
SELECT Manufacturer_ID, Manufacturer_Name
FROM Manufacturer
WHERE Manufacturer_ID IN (7, 68, 159);

-- Confirm no Ltd without period remain
SELECT COUNT(*) AS Remaining_Ltd_Without_Period
FROM Manufacturer
WHERE Manufacturer_Name LIKE '%Ltd' COLLATE Latin1_General_CS_AS;

-- Check for unintended side effects — any new duplicates?
SELECT Manufacturer_Name, COUNT(*) AS Count
FROM Manufacturer
GROUP BY Manufacturer_Name
HAVING COUNT(*) > 1;

-- =================================================
-- FIX 4: LOWERCASE LTD.
-- ID 236 'West-Coast pharmaceutical works ltd.' → '...Ltd.'
-- =================================================

-- Preview
SELECT Manufacturer_ID, Manufacturer_Name,
       REPLACE(Manufacturer_Name, 'ltd.', 'Ltd.') AS Fixed_Name
FROM Manufacturer
WHERE Manufacturer_Name LIKE '%ltd.' COLLATE Latin1_General_CS_AS;

-- Fix
UPDATE Manufacturer
SET Manufacturer_Name = REPLACE(Manufacturer_Name, 'ltd.', 'Ltd.')
WHERE Manufacturer_Name LIKE '%ltd.' COLLATE Latin1_General_CS_AS;

-- ==========================
-- VERIFY FIX 4
-- ==========================

-- Confirm fix was applied
SELECT Manufacturer_ID, Manufacturer_Name
FROM Manufacturer
WHERE Manufacturer_ID = 236;

-- Confirm no lowercase ltd. remain
SELECT COUNT(*) AS Remaining_Lowercase_Ltd
FROM Manufacturer
WHERE Manufacturer_Name LIKE '%ltd.' COLLATE Latin1_General_CS_AS;

-- =================================================
-- FIX 5: TYPO
-- ID 129 'Libra Pharmaceuticls Ltd.' → 'Libra Pharmaceuticals Ltd.'
-- Missing 'a' in Pharmaceuticals
-- =================================================

-- Preview
SELECT Manufacturer_ID, Manufacturer_Name,
       REPLACE(Manufacturer_Name, 'Pharmaceuticls', 'Pharmaceuticals') AS Fixed_Name
FROM Manufacturer
WHERE Manufacturer_ID = 129;

-- Fix
UPDATE Manufacturer
SET Manufacturer_Name = REPLACE(Manufacturer_Name, 'Libra Pharmaceuticls Ltd.', 'Libra Pharmaceuticals Ltd.')
WHERE Manufacturer_ID = 129;

-- ==========================
-- VERIFY FIX 5
-- ==========================

-- Confirm fix was applied
SELECT Manufacturer_ID, Manufacturer_Name
FROM Manufacturer
WHERE Manufacturer_ID = 129;

-- =================================================
-- FINAL SUMMARY
-- =================================================

SELECT
    COUNT(*)                                                           AS Total_Rows,
    SUM(CASE WHEN Manufacturer_Name IS NULL THEN 1 ELSE 0 END)        AS Null_Names,
    SUM(CASE WHEN LTRIM(RTRIM(Manufacturer_Name)) = ''
             THEN 1 ELSE 0 END)                                        AS Blank_Names,
    SUM(CASE WHEN Manufacturer_Name LIKE '%  %' THEN 1 ELSE 0 END)    AS Double_Spaces,
    SUM(CASE WHEN Manufacturer_Name COLLATE Latin1_General_BIN
             LIKE '%[^ -~]%' THEN 1 ELSE 0 END)                        AS Encoding_Issues,
    SUM(CASE WHEN Manufacturer_Name LIKE '%Ltd'
             COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END)           AS Ltd_Without_Period,
    SUM(CASE WHEN Manufacturer_Name LIKE '%ltd.'
             COLLATE Latin1_General_CS_AS THEN 1 ELSE 0 END)           AS Lowercase_Ltd
FROM Manufacturer;