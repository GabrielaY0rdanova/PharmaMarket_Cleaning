USE [$(DatabaseName)];
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @Failures TABLE (
    Check_Name nvarchar(200) NOT NULL,
    Actual_Value bigint NOT NULL,
    Expected_Value bigint NOT NULL
);

INSERT INTO @Failures
SELECT 'Drug_Class row count', COUNT_BIG(*), 422 FROM Drug_Class HAVING COUNT_BIG(*) <> 422
UNION ALL SELECT 'Dosage_Form row count', COUNT_BIG(*), 113 FROM Dosage_Form HAVING COUNT_BIG(*) <> 113
UNION ALL SELECT 'Manufacturer row count', COUNT_BIG(*), 240 FROM Manufacturer HAVING COUNT_BIG(*) <> 240
UNION ALL SELECT 'Indication row count', COUNT_BIG(*), 2043 FROM Indication HAVING COUNT_BIG(*) <> 2043
UNION ALL SELECT 'Generic row count', COUNT_BIG(*), 1711 FROM Generic HAVING COUNT_BIG(*) <> 1711
UNION ALL SELECT 'Medicine row count', COUNT_BIG(*), 21708 FROM Medicine HAVING COUNT_BIG(*) <> 21708
UNION ALL SELECT 'Medicine_PackageSize row count', COUNT_BIG(*), 14349 FROM Medicine_PackageSize HAVING COUNT_BIG(*) <> 14349
UNION ALL SELECT 'Medicine_PackageContainer row count', COUNT_BIG(*), 22707 FROM Medicine_PackageContainer HAVING COUNT_BIG(*) <> 22707
UNION ALL SELECT 'Generic_Indication row count', COUNT_BIG(*), 1608 FROM Generic_Indication HAVING COUNT_BIG(*) <> 1608;

INSERT INTO @Failures
SELECT 'Duplicate Drug_Class names', COUNT_BIG(*), 0
FROM (
    SELECT Drug_Class_Name FROM Drug_Class
    GROUP BY Drug_Class_Name HAVING COUNT_BIG(*) > 1
) AS duplicates
HAVING COUNT_BIG(*) <> 0;

INSERT INTO @Failures
SELECT 'Generic orphaned Drug_Class_ID', COUNT_BIG(*), 0
FROM Generic AS g
LEFT JOIN Drug_Class AS dc ON dc.Drug_Class_ID = g.Drug_Class_ID
WHERE dc.Drug_Class_ID IS NULL
HAVING COUNT_BIG(*) <> 0
UNION ALL
SELECT 'Medicine orphaned Dosage_Form_ID', COUNT_BIG(*), 0
FROM Medicine AS m
LEFT JOIN Dosage_Form AS df ON df.Dosage_Form_ID = m.Dosage_Form_ID
WHERE m.Dosage_Form_ID IS NOT NULL AND df.Dosage_Form_ID IS NULL
HAVING COUNT_BIG(*) <> 0
UNION ALL
SELECT 'Medicine orphaned Generic_ID', COUNT_BIG(*), 0
FROM Medicine AS m
LEFT JOIN Generic AS g ON g.Generic_ID = m.Generic_ID
WHERE m.Generic_ID IS NOT NULL AND g.Generic_ID IS NULL
HAVING COUNT_BIG(*) <> 0
UNION ALL
SELECT 'Medicine orphaned Manufacturer_ID', COUNT_BIG(*), 0
FROM Medicine AS m
LEFT JOIN Manufacturer AS mf ON mf.Manufacturer_ID = m.Manufacturer_ID
WHERE m.Manufacturer_ID IS NOT NULL AND mf.Manufacturer_ID IS NULL
HAVING COUNT_BIG(*) <> 0
UNION ALL
SELECT 'PackageSize orphaned Brand_ID', COUNT_BIG(*), 0
FROM Medicine_PackageSize AS ps
LEFT JOIN Medicine AS m ON m.Brand_ID = ps.Brand_ID
WHERE m.Brand_ID IS NULL
HAVING COUNT_BIG(*) <> 0
UNION ALL
SELECT 'PackageContainer orphaned Brand_ID', COUNT_BIG(*), 0
FROM Medicine_PackageContainer AS pc
LEFT JOIN Medicine AS m ON m.Brand_ID = pc.Brand_ID
WHERE m.Brand_ID IS NULL
HAVING COUNT_BIG(*) <> 0
UNION ALL
SELECT 'Generic_Indication orphaned Generic_ID', COUNT_BIG(*), 0
FROM Generic_Indication AS gi
LEFT JOIN Generic AS g ON g.Generic_ID = gi.Generic_ID
WHERE g.Generic_ID IS NULL
HAVING COUNT_BIG(*) <> 0
UNION ALL
SELECT 'Generic_Indication orphaned Indication_ID', COUNT_BIG(*), 0
FROM Generic_Indication AS gi
LEFT JOIN Indication AS i ON i.Indication_ID = gi.Indication_ID
WHERE i.Indication_ID IS NULL
HAVING COUNT_BIG(*) <> 0;

IF EXISTS (SELECT 1 FROM @Failures)
BEGIN
    SELECT Check_Name, Actual_Value, Expected_Value FROM @Failures ORDER BY Check_Name;
    THROW 50010, 'Cleaning validation gate failed.', 1;
END;

PRINT N'Cleaning validation gate passed.';
GO
