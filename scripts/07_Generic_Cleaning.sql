-- =================================================
-- 07_Generic_Cleaning.sql
-- Cleans the Generic table in PharmaMarketAnalytics_Clean
--
-- Issues found during inspection:
--   1. 2 encoding artifacts — garbled curly apostrophes
--      NCHAR(226) + NCHAR(8364) + NCHAR(8482) → NCHAR(8217) = '
--      Affected: Devil's Cotton + Ashoka bark + Aswagandha
--               St. John's Wort
--   2. 1 encoding artifact — garbled non-breaking spaces around plus sign
--      NCHAR(194) + '+' + NCHAR(194) → ' + '
--      Affected: Paracetamol + Tramadol Hydrochloride
--   3. 1 encoding artifact — garbled non-breaking space before 'Gel'
--      NCHAR(194) → single space ' '
--      Affected: Progesterone (Vaginal Gel)
--   4. 1 encoding artifact — garbled beta symbol
--      NCHAR(206) + NCHAR(178) → NCHAR(946) = β
--      Affected: β-Sitosterol (same issue as Drug_Class Fix 4)
--
-- No NULLs, blanks, duplicates, whitespace issues, or comma issues found.
-- All garbled sequences identified via the discovery query below —
-- no IDs hardcoded anywhere in this script.
--
-- Note: Fix 2 must run before Fix 3 — both target NCHAR(194) but
-- Fix 2 is a more specific pattern. Running Fix 3 first would consume
-- the NCHAR(194) bytes that Fix 2 depends on.
--
-- Drug_Class_ID = 0 generics (61 rows) are documented in the N/A
-- profiling section below and left unchanged — not fixable without
-- external research.
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- =================================================
-- INSPECTION
-- =================================================

-- Full table preview
SELECT *
FROM Generic;

-- All distinct generic names
SELECT DISTINCT Generic_Name
FROM Generic
ORDER BY Generic_Name;

-- NULL check
SELECT COUNT(*) AS Null_Names
FROM Generic
WHERE Generic_Name IS NULL;

-- Blank check
SELECT COUNT(*) AS Blank_Names
FROM Generic
WHERE LTRIM(RTRIM(Generic_Name)) = '';

-- Duplicate check
SELECT Generic_Name, COUNT(*) AS Count
FROM Generic
GROUP BY Generic_Name
HAVING COUNT(*) > 1
ORDER BY Generic_Name;

-- Encoding artifacts (non-ASCII characters)
SELECT Generic_ID, Generic_Name
FROM Generic
WHERE Generic_Name COLLATE Latin1_General_BIN
      LIKE '%[^ -~]%';

-- Character code discovery
-- Find all distinct non-ASCII sequences in Generic_Name
-- Run this before writing any fix to identify exact byte sequences
WITH Non_ASCII_Positions AS (
    SELECT
        Generic_ID,
        Generic_Name,
        PATINDEX('%[^ -~]%' COLLATE Latin1_General_BIN, Generic_Name) AS First_Bad_Pos
    FROM Generic
    WHERE Generic_Name COLLATE Latin1_General_BIN LIKE '%[^ -~]%'
)
SELECT DISTINCT
    UNICODE(SUBSTRING(Generic_Name, First_Bad_Pos,     1)) AS Char1,
    UNICODE(SUBSTRING(Generic_Name, First_Bad_Pos + 1, 1)) AS Char2,
    UNICODE(SUBSTRING(Generic_Name, First_Bad_Pos + 2, 1)) AS Char3,
    MIN(Generic_Name)                                       AS Example_Name,
    COUNT(*)                                                AS Affected_Rows
FROM Non_ASCII_Positions
GROUP BY
    UNICODE(SUBSTRING(Generic_Name, First_Bad_Pos,     1)),
    UNICODE(SUBSTRING(Generic_Name, First_Bad_Pos + 1, 1)),
    UNICODE(SUBSTRING(Generic_Name, First_Bad_Pos + 2, 1))
ORDER BY Affected_Rows DESC;
-- Results:
-- Char1=226, Char2=8364, Char3=8482 → garbled ' (NCHAR 8217), 2 rows
-- Char1=194, Char2=43,   Char3=194  → garbled NBSP around '+', 1 row
-- Char1=194, Char2=71,   Char3=101  → garbled NBSP before 'Gel' (194 only, 71/101 are 'G','e'), 1 row
-- Char1=206, Char2=178,  Char3=45   → garbled β (206+178 only, 45 is '-'), 1 row

-- Whitespace check
SELECT COUNT(*) AS Whitespace_Issues
FROM Generic
WHERE Generic_Name != LTRIM(RTRIM(Generic_Name));

-- Comma check
SELECT Generic_ID, Generic_Name
FROM Generic
WHERE Generic_Name LIKE '%,%'
ORDER BY Generic_Name;

-- ==========================
-- N/A DRUG CLASS PROFILING
-- Drug_Class_ID = 0 generics are not fixable without external research.
-- Documented here for completeness.
-- ==========================

-- Count
SELECT COUNT(*) AS NA_Generic_Count
FROM Generic
WHERE Drug_Class_ID = 0;

-- Full list
SELECT Generic_ID, Generic_Name, Slug
FROM Generic
WHERE Drug_Class_ID = 0
ORDER BY Generic_Name;

-- How many are referenced in Medicine?
SELECT COUNT(*) AS NA_Generics_Used_In_Medicine
FROM Generic g
INNER JOIN Medicine m ON g.Generic_ID = m.Generic_ID
WHERE g.Drug_Class_ID = 0;

-- Drug class distribution (spot any suspicious outliers)
SELECT
    dc.Drug_Class_ID,
    dc.Drug_Class_Name,
    COUNT(g.Generic_ID) AS Generic_Count
FROM Drug_Class dc
LEFT JOIN Generic g ON dc.Drug_Class_ID = g.Drug_Class_ID
GROUP BY dc.Drug_Class_ID, dc.Drug_Class_Name
ORDER BY Generic_Count DESC;

-- =================================================
-- FIX 1: GARBLED CURLY APOSTROPHES
-- NCHAR(226) + NCHAR(8364) + NCHAR(8482) → NCHAR(8217) = '
-- 2 rows: Devil's Cotton + Ashoka bark + Aswagandha
--         St. John's Wort
-- =================================================

-- Preview
SELECT
    Generic_ID,
    Generic_Name AS Current_Name,
    REPLACE(
        Generic_Name,
        NCHAR(226) + NCHAR(8364) + NCHAR(8482),
        NCHAR(8217)
    ) AS Fixed_Name
FROM Generic
WHERE Generic_Name LIKE '%' + NCHAR(226) + NCHAR(8364) + NCHAR(8482) + '%';

-- Fix
UPDATE Generic
SET Generic_Name = REPLACE(
        Generic_Name,
        NCHAR(226) + NCHAR(8364) + NCHAR(8482),
        NCHAR(8217)
    )
WHERE Generic_Name LIKE '%' + NCHAR(226) + NCHAR(8364) + NCHAR(8482) + '%';

-- ==========================
-- VERIFY FIX 1
-- ==========================

-- Confirm fix was applied
SELECT Generic_ID, Generic_Name
FROM Generic
WHERE Generic_Name LIKE '%' + NCHAR(8217) + '%';

-- Confirm no garbled apostrophe sequences remain
SELECT COUNT(*) AS Remaining_Garbled_Apostrophes
FROM Generic
WHERE Generic_Name LIKE '%' + NCHAR(226) + NCHAR(8364) + NCHAR(8482) + '%';

-- Check for unintended side effects — any new duplicates?
SELECT Generic_Name, COUNT(*) AS Count
FROM Generic
GROUP BY Generic_Name
HAVING COUNT(*) > 1;

-- =================================================
-- FIX 2: GARBLED NON-BREAKING SPACES AROUND PLUS SIGN
-- NCHAR(194) + '+' + NCHAR(194) → ' + '
-- 1 row: Paracetamol + Tramadol Hydrochloride
-- Must run before Fix 3 — Fix 3 targets NCHAR(194) broadly
-- =================================================

-- Preview
SELECT
    Generic_ID,
    Generic_Name AS Current_Name,
    REPLACE(
        Generic_Name,
        NCHAR(194) + '+' + NCHAR(194),
        ' + '
    ) AS Fixed_Name
FROM Generic
WHERE Generic_Name LIKE '%' + NCHAR(194) + '+' + NCHAR(194) + '%';

-- Fix
UPDATE Generic
SET Generic_Name = REPLACE(
        Generic_Name,
        NCHAR(194) + '+' + NCHAR(194),
        ' + '
    )
WHERE Generic_Name LIKE '%' + NCHAR(194) + '+' + NCHAR(194) + '%';

-- ==========================
-- VERIFY FIX 2
-- ==========================

-- Confirm fix was applied
SELECT Generic_ID, Generic_Name
FROM Generic
WHERE Generic_Name LIKE '%Paracetamol%Tramadol%';

-- Confirm no garbled sequence remains
SELECT COUNT(*) AS Remaining_Garbled_NBSP_Plus
FROM Generic
WHERE Generic_Name LIKE '%' + NCHAR(194) + '+' + NCHAR(194) + '%';

-- =================================================
-- FIX 3: GARBLED NON-BREAKING SPACE BEFORE 'GEL'
-- NCHAR(194) → single space ' '
-- 1 row: Progesterone (Vaginal Gel)
-- Runs after Fix 2 — any NCHAR(194) + '+' + NCHAR(194)
-- patterns are already resolved by this point
-- =================================================

-- Preview
SELECT
    Generic_ID,
    Generic_Name AS Current_Name,
    REPLACE(Generic_Name, NCHAR(194), ' ') AS Fixed_Name
FROM Generic
WHERE Generic_Name LIKE '%' + NCHAR(194) + '%';

-- Fix
UPDATE Generic
SET Generic_Name = REPLACE(Generic_Name, NCHAR(194), ' ')
WHERE Generic_Name LIKE '%' + NCHAR(194) + '%';

-- ==========================
-- VERIFY FIX 3
-- ==========================

-- Confirm fix was applied
SELECT Generic_ID, Generic_Name
FROM Generic
WHERE Generic_Name LIKE '%Vaginal%Gel%';

-- Confirm no garbled NBSP remains
SELECT COUNT(*) AS Remaining_Garbled_NBSP
FROM Generic
WHERE Generic_Name LIKE '%' + NCHAR(194) + '%';

-- =================================================
-- FIX 4: GARBLED BETA SYMBOL
-- NCHAR(206) + NCHAR(178) → NCHAR(946) = β
-- 1 row: β-Sitosterol
-- Same encoding issue as Drug_Class Fix 4
-- =================================================

-- Preview
SELECT
    Generic_ID,
    Generic_Name AS Current_Name,
    REPLACE(
        Generic_Name,
        NCHAR(206) + NCHAR(178),
        NCHAR(946)
    ) AS Fixed_Name
FROM Generic
WHERE Generic_Name LIKE '%' + NCHAR(206) + NCHAR(178) + '%';

-- Fix
UPDATE Generic
SET Generic_Name = REPLACE(
        Generic_Name,
        NCHAR(206) + NCHAR(178),
        NCHAR(946)
    )
WHERE Generic_Name LIKE '%' + NCHAR(206) + NCHAR(178) + '%';

-- ==========================
-- VERIFY FIX 4
-- ==========================

-- Confirm fix was applied
SELECT Generic_ID, Generic_Name
FROM Generic
WHERE Generic_Name LIKE '%' + NCHAR(946) + '%';

-- Confirm no garbled beta sequence remains
SELECT COUNT(*) AS Remaining_Garbled_Beta
FROM Generic
WHERE Generic_Name LIKE '%' + NCHAR(206) + NCHAR(178) + '%';

-- =================================================
-- FINAL SUMMARY
-- All four garbled sequence counts should be 0.
-- NCHAR(8217) and NCHAR(946) are intentional Unicode —
-- not artifacts — so they are not flagged here.
-- Drug_Class_ID = 0 generics are documented above
-- and left unchanged intentionally.
-- =================================================

-- Confirm no unexpected encoding issues remain in any row
-- Note: NCHAR(8217) apostrophes and NCHAR(946) beta are intentional
--       Unicode characters, not encoding artifacts — expected to appear
--       in the non-ASCII check below
SELECT Generic_ID, Generic_Name
FROM Generic
WHERE Generic_Name COLLATE Latin1_General_BIN
      LIKE '%[^ -~]%';

-- Final row counts and issue summary
-- All garbled sequence counts should be 0
-- NA_Drug_Class = 61 is expected — documented in N/A profiling section above
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
    SUM(CASE WHEN Drug_Class_ID = 0 THEN 1 ELSE 0 END)                   AS NA_Drug_Class
FROM Generic;
GO