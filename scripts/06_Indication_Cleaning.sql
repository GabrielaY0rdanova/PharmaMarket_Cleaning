-- =================================================
-- 06_Indication_Cleaning.sql
-- Cleans the Indication table in PharmaMarketAnalytics_Clean
--
-- Issues found during inspection:
--   1. 22 encoding artifacts — garbled curly apostrophes
--      NCHAR(226) + NCHAR(8364) + NCHAR(8482) → NCHAR(8217) = '
--   2. 1 encoding artifact — garbled non-breaking space
--      NCHAR(194) only → single space ' '
--      (NCHAR(111) and NCHAR(114) following it are regular 'o' and 'r')
--   3. 1 encoding artifact — garbled umlaut ö
--      NCHAR(195) + NCHAR(182) → NCHAR(246) = ö
--      (NCHAR(109) following it is regular 'm')
--
-- No NULLs, blanks, duplicates, or comma issues found.
-- All garbled sequences identified via the discovery query below —
-- no IDs hardcoded anywhere in this script.
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- =================================================
-- INSPECTION
-- =================================================

-- Full table preview
SELECT *
FROM Indication;

-- All distinct indication names
SELECT DISTINCT Indication_Name
FROM Indication
ORDER BY Indication_Name;

-- NULL check
SELECT COUNT(*) AS Null_Names
FROM Indication
WHERE Indication_Name IS NULL;

-- Blank check
SELECT COUNT(*) AS Blank_Names
FROM Indication
WHERE LTRIM(RTRIM(Indication_Name)) = '';

-- Duplicate check
SELECT Indication_Name, COUNT(*) AS Count
FROM Indication
GROUP BY Indication_Name
HAVING COUNT(*) > 1
ORDER BY Indication_Name;

-- Encoding artifacts (non-ASCII characters)
SELECT Indication_ID, Indication_Name
FROM Indication
WHERE Indication_Name COLLATE Latin1_General_BIN
      LIKE '%[^ -~]%';

-- =================================================
-- CHARACTER CODE DISCOVERY
-- Find all distinct non-ASCII sequences in Indication_Name
-- Run this before writing any fix to identify exact byte sequences
-- =================================================

WITH Non_ASCII_Positions AS (
    SELECT
        Indication_ID,
        Indication_Name,
        PATINDEX('%[^ -~]%' COLLATE Latin1_General_BIN, Indication_Name) AS First_Bad_Pos
    FROM Indication
    WHERE Indication_Name COLLATE Latin1_General_BIN LIKE '%[^ -~]%'
)
SELECT DISTINCT
    UNICODE(SUBSTRING(Indication_Name, First_Bad_Pos,     1)) AS Char1,
    UNICODE(SUBSTRING(Indication_Name, First_Bad_Pos + 1, 1)) AS Char2,
    UNICODE(SUBSTRING(Indication_Name, First_Bad_Pos + 2, 1)) AS Char3,
    MIN(Indication_Name)                                       AS Example_Name,
    COUNT(*)                                                   AS Affected_Rows
FROM Non_ASCII_Positions
GROUP BY
    UNICODE(SUBSTRING(Indication_Name, First_Bad_Pos,     1)),
    UNICODE(SUBSTRING(Indication_Name, First_Bad_Pos + 1, 1)),
    UNICODE(SUBSTRING(Indication_Name, First_Bad_Pos + 2, 1))
ORDER BY Affected_Rows DESC;
-- Results:
-- Char1=226, Char2=8364, Char3=8482 → garbled ' (NCHAR 8217), 22 rows
-- Char1=194, Char2=111,  Char3=114  → garbled NBSP (194 only, 111/114 are 'o','r'), 1 row
-- Char1=195, Char2=182,  Char3=109  → garbled ö (195+182 only, 109 is 'm'), 1 row

-- =================================================
-- FIX 1: GARBLED CURLY APOSTROPHES
-- NCHAR(226) + NCHAR(8364) + NCHAR(8482) → NCHAR(8217) = '
-- 22 rows
-- =================================================

-- Preview
SELECT
    Indication_ID,
    Indication_Name AS Current_Name,
    REPLACE(
        Indication_Name,
        NCHAR(226) + NCHAR(8364) + NCHAR(8482),
        NCHAR(8217)
    ) AS Fixed_Name
FROM Indication
WHERE Indication_Name LIKE '%' + NCHAR(226) + NCHAR(8364) + NCHAR(8482) + '%';

-- Fix
UPDATE Indication
SET Indication_Name = REPLACE(
        Indication_Name,
        NCHAR(226) + NCHAR(8364) + NCHAR(8482),
        NCHAR(8217)
    )
WHERE Indication_Name LIKE '%' + NCHAR(226) + NCHAR(8364) + NCHAR(8482) + '%';

-- ==========================
-- VERIFY FIX 1
-- ==========================

-- Confirm fixed rows now contain the correct curly apostrophe
SELECT Indication_ID, Indication_Name
FROM Indication
WHERE Indication_Name LIKE '%' + NCHAR(8217) + '%'
ORDER BY Indication_ID;

-- Confirm no garbled apostrophe sequences remain
SELECT COUNT(*) AS Remaining_Garbled_Apostrophes
FROM Indication
WHERE Indication_Name LIKE '%' + NCHAR(226) + NCHAR(8364) + NCHAR(8482) + '%';

-- Check for unintended side effects — any new duplicates?
SELECT Indication_Name, COUNT(*) AS Count
FROM Indication
GROUP BY Indication_Name
HAVING COUNT(*) > 1
ORDER BY Indication_Name;

-- =================================================
-- FIX 2: GARBLED NON-BREAKING SPACE
-- NCHAR(194) only → single space ' '
-- 1 row
-- =================================================

-- Preview
SELECT
    Indication_ID,
    Indication_Name AS Current_Name,
    REPLACE(Indication_Name, NCHAR(194), ' ') AS Fixed_Name
FROM Indication
WHERE Indication_Name LIKE '%' + NCHAR(194) + '%';

-- Fix
UPDATE Indication
SET Indication_Name = REPLACE(Indication_Name, NCHAR(194), ' ')
WHERE Indication_Name LIKE '%' + NCHAR(194) + '%';

-- ==========================
-- VERIFY FIX 2
-- ==========================

-- Confirm fix was applied
SELECT Indication_ID, Indication_Name
FROM Indication
WHERE Indication_Name LIKE '%or mucocutaneous%';

-- Confirm no garbled NBSP remains
SELECT COUNT(*) AS Remaining_Garbled_NBSP
FROM Indication
WHERE Indication_Name LIKE '%' + NCHAR(194) + '%';

-- =================================================
-- FIX 3: GARBLED UMLAUT
-- NCHAR(195) + NCHAR(182) → NCHAR(246) = ö
-- 1 row — apostrophe in this row already corrected by Fix 1
-- =================================================

-- Preview
SELECT
    Indication_ID,
    Indication_Name AS Current_Name,
    REPLACE(
        Indication_Name,
        NCHAR(195) + NCHAR(182),
        NCHAR(246)
    ) AS Fixed_Name
FROM Indication
WHERE Indication_Name LIKE '%' + NCHAR(195) + NCHAR(182) + '%';

-- Fix
UPDATE Indication
SET Indication_Name = REPLACE(
        Indication_Name,
        NCHAR(195) + NCHAR(182),
        NCHAR(246)
    )
WHERE Indication_Name LIKE '%' + NCHAR(195) + NCHAR(182) + '%';

-- ==========================
-- VERIFY FIX 3
-- ==========================

-- Confirm fix was applied
SELECT Indication_ID, Indication_Name
FROM Indication
WHERE Indication_Name LIKE '%' + NCHAR(246) + '%';

-- Confirm no garbled umlaut sequence remains
SELECT COUNT(*) AS Remaining_Garbled_Umlaut
FROM Indication
WHERE Indication_Name LIKE '%' + NCHAR(195) + NCHAR(182) + '%';

-- =================================================
-- FINAL SUMMARY
-- All three garbled sequence counts should be 0.
-- NCHAR(8217) and NCHAR(246) are intentional Unicode —
-- not artifacts — so they are not flagged here.
-- =================================================

-- Confirm no unexpected encoding issues remain in any row
SELECT Indication_ID, Indication_Name
FROM Indication
WHERE Indication_Name COLLATE Latin1_General_BIN
      LIKE '%[^ -~]%';

-- Final row counts and issue summary
-- All garbled sequence counts should be 0
-- Remaining non-ASCII characters (NCHAR 8217 and 8246) are intentional Unicode
SELECT
    COUNT(*)                                                          AS Total_Rows,
    SUM(CASE WHEN Indication_Name IS NULL THEN 1 ELSE 0 END)         AS Null_Names,
    SUM(CASE WHEN LTRIM(RTRIM(Indication_Name)) = ''
             THEN 1 ELSE 0 END)                                       AS Blank_Names,
    SUM(CASE WHEN Indication_Name LIKE
             '%' + NCHAR(226) + NCHAR(8364) + NCHAR(8482) + '%'
             THEN 1 ELSE 0 END)                                       AS Garbled_Apostrophes,
    SUM(CASE WHEN Indication_Name LIKE '%' + NCHAR(194) + '%'
             THEN 1 ELSE 0 END)                                       AS Garbled_NBSP,
    SUM(CASE WHEN Indication_Name LIKE
             '%' + NCHAR(195) + NCHAR(182) + '%'
             THEN 1 ELSE 0 END)                                       AS Garbled_Umlaut
FROM Indication;
GO
