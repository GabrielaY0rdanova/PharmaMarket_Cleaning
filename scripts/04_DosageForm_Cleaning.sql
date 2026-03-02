-- =================================================
-- 04_DosageForm_Cleaning.sql
-- Cleans the Dosage_Form table in PharmaMarketAnalytics_Clean
--
-- Issues found during inspection:
--   1. 1 capitalisation inconsistency:
--      'Emulsion for infusion' should be 'Emulsion for Infusion'
--      to match the title case convention used across all other rows
--
-- No NULLs, blanks, duplicates, comma issues, or encoding artifacts found.
-- All 113 dosage forms are distinct and legitimate pharmaceutical terms.
-- Route of administration abbreviations (IV, IM, SC, IA etc.) refer to
-- different anatomical targets and are not duplicates of their full forms.
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- =================================================
-- INSPECTION
-- =================================================

-- Full table preview
SELECT * FROM Dosage_Form;

-- All distinct dosage form names
SELECT DISTINCT Dosage_Form_Name
FROM Dosage_Form
ORDER BY Dosage_Form_Name;

-- NULL check
SELECT COUNT(*) AS Null_Names
FROM Dosage_Form
WHERE Dosage_Form_Name IS NULL;

-- Blank check
SELECT COUNT(*) AS Blank_Names
FROM Dosage_Form
WHERE LTRIM(RTRIM(Dosage_Form_Name)) = '';

-- Duplicate check
SELECT Dosage_Form_Name, COUNT(*) AS Count
FROM Dosage_Form
GROUP BY Dosage_Form_Name
HAVING COUNT(*) > 1
ORDER BY Dosage_Form_Name;

-- Comma and period issues
SELECT Dosage_Form_ID, Dosage_Form_Name
FROM Dosage_Form
WHERE Dosage_Form_Name LIKE '%,%'
   OR Dosage_Form_Name LIKE '%.%';

-- Encoding artifacts
SELECT Dosage_Form_ID, Dosage_Form_Name
FROM Dosage_Form
WHERE Dosage_Form_Name COLLATE Latin1_General_BIN
      LIKE '%[^ -~]%';

-- Common misspellings
SELECT Dosage_Form_ID, Dosage_Form_Name
FROM Dosage_Form
WHERE Dosage_Form_Name LIKE '%njection%'
   OR Dosage_Form_Name LIKE '%ablet%'
   OR Dosage_Form_Name LIKE '%apsule%'
   OR Dosage_Form_Name LIKE '%olution%'
   OR Dosage_Form_Name LIKE '%uspension%'
ORDER BY Dosage_Form_Name;

-- Capitalisation inconsistency check
-- 'Emulsion for infusion' uses lowercase 'infusion'
-- while all other multi-word names use title case
SELECT Dosage_Form_ID, Dosage_Form_Name
FROM Dosage_Form
WHERE Dosage_Form_Name LIKE '% for %'
   OR Dosage_Form_Name LIKE '% or %'
ORDER BY Dosage_Form_Name;

-- =================================================
-- FIX 1: CAPITALISATION INCONSISTENCY
-- 'Emulsion for infusion' → 'Emulsion for Infusion'
-- =================================================

-- Preview
SELECT
    Dosage_Form_ID,
    Dosage_Form_Name                                    AS Current_Name,
    'Emulsion for Infusion'                             AS Fixed_Name
FROM Dosage_Form
WHERE Dosage_Form_Name = 'Emulsion for infusion';

-- Fix
UPDATE Dosage_Form
SET Dosage_Form_Name = 'Emulsion for Infusion'
WHERE Dosage_Form_Name = 'Emulsion for infusion';

-- ==========================
-- VERIFY FIX 1
-- ==========================

-- Confirm fix was applied
SELECT Dosage_Form_ID, Dosage_Form_Name
FROM Dosage_Form
WHERE Dosage_Form_ID = 19;

-- Check for unintended side effects — any new duplicates?
SELECT Dosage_Form_Name, COUNT(*) AS Count
FROM Dosage_Form
GROUP BY Dosage_Form_Name
HAVING COUNT(*) > 1;

-- =================================================
-- FINAL SUMMARY
-- =================================================

SELECT
    COUNT(*)                                                          AS Total_Rows,
    SUM(CASE WHEN Dosage_Form_Name IS NULL THEN 1 ELSE 0 END)        AS Null_Names,
    SUM(CASE WHEN LTRIM(RTRIM(Dosage_Form_Name)) = ''
             THEN 1 ELSE 0 END)                                       AS Blank_Names,
    SUM(CASE WHEN Dosage_Form_Name LIKE '%,%' THEN 1 ELSE 0 END)     AS Comma_Issues,
    SUM(CASE WHEN Dosage_Form_Name COLLATE Latin1_General_BIN
             LIKE '%[^ -~]%' THEN 1 ELSE 0 END)                      AS Encoding_Issues
FROM Dosage_Form;
