-- =================================================
-- 11_GenericIndication_Cleaning.sql
-- Cleans the Generic_Indication table in PharmaMarketAnalytics_Clean
--
-- STRUCTURE: 1,608 rows
--   1,608 distinct generics, each with exactly 1 indication
--   662 distinct indications referenced (many shared across generics)
--
-- NULL PROFILE:
--   Generic_ID    : 0 NULL -- clean
--   Indication_ID : 0 NULL -- clean
--
-- DUPLICATES: None found.
--
-- REFERENTIAL INTEGRITY:
--   Orphaned Generic_IDs    : 0 -- all Generic_IDs exist in Generic
--   Orphaned Indication_IDs : 0 -- all Indication_IDs exist in Indication
--
-- N/A GENERICS: 9 pairs involve generics with Drug_Class_ID = 0.
--   Not an error -- these generics are valid, their drug class is
--   simply unresolvable from source data. Pairs are kept as-is.
--
-- CONCLUSION: No UPDATE or DELETE statements required.
--   Generic_Indication table is accepted as-is.
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- =================================================
-- INSPECTION
-- =================================================

-- Full table preview
SELECT * FROM Generic_Indication;

-- Row count
SELECT COUNT(*) AS Total_Rows FROM Generic_Indication;

-- NULL check
SELECT
    SUM(CASE WHEN Generic_ID IS NULL THEN 1 ELSE 0 END)     AS Null_Generic_ID,
    SUM(CASE WHEN Indication_ID IS NULL THEN 1 ELSE 0 END)  AS Null_Indication_ID
FROM Generic_Indication;

-- Duplicate check
SELECT Generic_ID, Indication_ID, COUNT(*) AS Count
FROM Generic_Indication
GROUP BY Generic_ID, Indication_ID
HAVING COUNT(*) > 1
ORDER BY Count DESC;

-- Orphaned Generic_IDs — no matching row in Generic
SELECT COUNT(*) AS Orphaned_Generic_IDs
FROM Generic_Indication gi
LEFT JOIN Generic g ON gi.Generic_ID = g.Generic_ID
WHERE g.Generic_ID IS NULL;

-- Orphaned Indication_IDs — no matching row in Indication
SELECT COUNT(*) AS Orphaned_Indication_IDs
FROM Generic_Indication gi
LEFT JOIN Indication i ON gi.Indication_ID = i.Indication_ID
WHERE i.Indication_ID IS NULL;

-- Distinct generics and indications covered
SELECT
    COUNT(DISTINCT Generic_ID)    AS Distinct_Generics,
    COUNT(DISTINCT Indication_ID) AS Distinct_Indications
FROM Generic_Indication;

-- Pairs involving N/A generics (Drug_Class_ID = 0)
-- Not an error — documented for completeness
SELECT COUNT(*) AS NA_Generic_Pairs
FROM Generic_Indication gi
INNER JOIN Generic g ON gi.Generic_ID = g.Generic_ID
WHERE g.Drug_Class_ID = 0;

-- Distribution — indications per generic
SELECT
    Indications_Per_Generic,
    COUNT(*) AS Generic_Count
FROM (
    SELECT Generic_ID, COUNT(*) AS Indications_Per_Generic
    FROM Generic_Indication
    GROUP BY Generic_ID
) counts
GROUP BY Indications_Per_Generic
ORDER BY Indications_Per_Generic;

-- =================================================
-- NO FIXES APPLIED
-- =================================================
-- Table is fully clean. All foreign keys are valid,
-- no NULLs, no duplicates.
-- The 9 pairs involving N/A generics are intentionally
-- kept — the generic data is valid even if drug class
-- is unresolvable.
-- =================================================

-- =================================================
-- FINAL SUMMARY
-- =================================================

SELECT
    COUNT(*)                                                         AS Total_Rows,
    SUM(CASE WHEN Generic_ID IS NULL THEN 1 ELSE 0 END)             AS Null_Generic_ID,
    SUM(CASE WHEN Indication_ID IS NULL THEN 1 ELSE 0 END)          AS Null_Indication_ID,
    COUNT(DISTINCT Generic_ID)                                       AS Distinct_Generics,
    COUNT(DISTINCT Indication_ID)                                    AS Distinct_Indications
FROM Generic_Indication;
-- Expected: 1608 | 0 | 0 | 1608 | 662
GO