-- =================================================
-- 02_LoadSourceData.sql
-- Creates all tables and loads post-ETL, pre-cleaning
-- snapshots from source_data/ into PharmaMarketAnalytics_Clean
--
-- Source CSVs were exported from PharmaMarketAnalytics
-- using 01_ExportSourceData.py (pandas/pyodbc).
-- This ensures proper handling of commas and special
-- characters in the data.
--
-- Table load order respects FK dependencies:
--   Drug_Class → Generic → Medicine → Medicine_PackageSize
--                                   → Medicine_PackageContainer
--   Dosage_Form → Medicine
--   Manufacturer → Medicine
--   Indication → Generic_Indication
--   Generic → Generic_Indication
--
-- IMPORTANT: Update the file path to match your local machine.
-- =================================================

USE PharmaMarketAnalytics_Clean;
GO

-- ==========================
-- DROP tables in reverse dependency order
-- ==========================
DROP TABLE IF EXISTS Generic_Indication;
DROP TABLE IF EXISTS Medicine_PackageContainer;
DROP TABLE IF EXISTS Medicine_PackageSize;
DROP TABLE IF EXISTS Medicine;
DROP TABLE IF EXISTS Generic;
DROP TABLE IF EXISTS Drug_Class;
DROP TABLE IF EXISTS Dosage_Form;
DROP TABLE IF EXISTS Manufacturer;
DROP TABLE IF EXISTS Indication;
GO

-- ==========================
-- CREATE and LOAD Drug_Class
-- ==========================
CREATE TABLE Drug_Class (
    Drug_Class_ID   INT PRIMARY KEY,
    Drug_Class_Name NVARCHAR(255) NOT NULL,
    Slug            NVARCHAR(255)
);

BULK INSERT Drug_Class
FROM 'E:\Data Analysis\My Projects\PharmaMarket_Cleaning\source_data\Drug_Class.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    TABLOCK
);

SELECT COUNT(*) AS Drug_Class_Count FROM Drug_Class;
GO

-- ==========================
-- CREATE and LOAD Dosage_Form
-- ==========================
CREATE TABLE Dosage_Form (
    Dosage_Form_ID   INT PRIMARY KEY,
    Dosage_Form_Name NVARCHAR(255) NOT NULL,
    Slug             NVARCHAR(255)
);

BULK INSERT Dosage_Form
FROM 'E:\Data Analysis\My Projects\PharmaMarket_Cleaning\source_data\Dosage_Form.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    TABLOCK
);

SELECT COUNT(*) AS Dosage_Form_Count FROM Dosage_Form;
GO

-- ==========================
-- CREATE and LOAD Manufacturer
-- ==========================
CREATE TABLE Manufacturer (
    Manufacturer_ID   INT PRIMARY KEY,
    Manufacturer_Name NVARCHAR(255) NOT NULL,
    Slug              NVARCHAR(255)
);

BULK INSERT Manufacturer
FROM 'E:\Data Analysis\My Projects\PharmaMarket_Cleaning\source_data\Manufacturer.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    TABLOCK
);

SELECT COUNT(*) AS Manufacturer_Count FROM Manufacturer;
GO

-- ==========================
-- CREATE and LOAD Indication
-- ==========================
CREATE TABLE Indication (
    Indication_ID   INT PRIMARY KEY,
    Indication_Name NVARCHAR(500) NOT NULL,
    Slug            NVARCHAR(500)
);

BULK INSERT Indication
FROM 'E:\Data Analysis\My Projects\PharmaMarket_Cleaning\source_data\Indication.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    TABLOCK
);

SELECT COUNT(*) AS Indication_Count FROM Indication;
GO

-- ==========================
-- CREATE and LOAD Generic
-- ==========================
CREATE TABLE Generic (
    Generic_ID    INT PRIMARY KEY,
    Generic_Name  NVARCHAR(255) NOT NULL,
    Slug          NVARCHAR(255),
    Drug_Class_ID INT NOT NULL,

    CONSTRAINT FK_Generic_DrugClass
        FOREIGN KEY (Drug_Class_ID)
        REFERENCES Drug_Class(Drug_Class_ID)
);

BULK INSERT Generic
FROM 'E:\Data Analysis\My Projects\PharmaMarket_Cleaning\source_data\Generic.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    TABLOCK
);

SELECT COUNT(*) AS Generic_Count FROM Generic;
GO

-- ==========================
-- CREATE and LOAD Medicine
--
-- Uses staging because Generic_ID and Manufacturer_ID
-- can be NULL in the source data — TRY_CAST handles
-- the conversion safely.
--
-- Package_Container, Package_Size, and Unit_Price are
-- not present in this table — they were split into
-- Medicine_PackageSize and Medicine_PackageContainer
-- by the ETL project (scripts 07 and 07b).
-- ==========================
CREATE TABLE Medicine (
    Brand_ID        INT PRIMARY KEY,
    Brand_Name      NVARCHAR(255),
    Type            NVARCHAR(255),
    Slug            NVARCHAR(255),
    Dosage_Form_ID  INT,
    Generic_ID      INT,
    Strength        NVARCHAR(255),
    Manufacturer_ID INT,

    CONSTRAINT FK_Medicine_DosageForm
        FOREIGN KEY (Dosage_Form_ID)
        REFERENCES Dosage_Form(Dosage_Form_ID),

    CONSTRAINT FK_Medicine_Generic
        FOREIGN KEY (Generic_ID)
        REFERENCES Generic(Generic_ID),

    CONSTRAINT FK_Medicine_Manufacturer
        FOREIGN KEY (Manufacturer_ID)
        REFERENCES Manufacturer(Manufacturer_ID)
);

DROP TABLE IF EXISTS Staging_Medicine;

CREATE TABLE Staging_Medicine (
    Brand_ID        INT,
    Brand_Name      NVARCHAR(255),
    Type            NVARCHAR(255),
    Slug            NVARCHAR(255),
    Dosage_Form_ID  NVARCHAR(50),
    Generic_ID      NVARCHAR(50),
    Strength        NVARCHAR(255),
    Manufacturer_ID NVARCHAR(50)
);

BULK INSERT Staging_Medicine
FROM 'E:\Data Analysis\My Projects\PharmaMarket_Cleaning\source_data\Medicine.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    TABLOCK
);

INSERT INTO Medicine (
    Brand_ID, Brand_Name, Type, Slug,
    Dosage_Form_ID, Generic_ID, Strength, Manufacturer_ID
)
SELECT
    Brand_ID, Brand_Name, Type, Slug,
    TRY_CAST(Dosage_Form_ID AS INT),
    TRY_CAST(TRY_CAST(Generic_ID      AS FLOAT) AS INT),
    Strength,
    TRY_CAST(TRY_CAST(Manufacturer_ID AS FLOAT) AS INT)
FROM Staging_Medicine;

DROP TABLE Staging_Medicine;

SELECT COUNT(*) AS Medicine_Count FROM Medicine;
GO

-- ==========================
-- CREATE and LOAD Medicine_PackageSize
--
-- Child table of Medicine — one row per pack size option.
-- Pack_Size is the unit count (e.g. 30, 100).
-- Pack_Price is the price for that pack in BDT.
-- ==========================
CREATE TABLE Medicine_PackageSize (
    PackageSize_ID  INT PRIMARY KEY,
    Brand_ID        INT NOT NULL,
    Pack_Size       INT,
    Pack_Price      DECIMAL(10,2),

    CONSTRAINT FK_PackageSize_Medicine
        FOREIGN KEY (Brand_ID)
        REFERENCES Medicine(Brand_ID)
);

BULK INSERT Medicine_PackageSize
FROM 'E:\Data Analysis\My Projects\PharmaMarket_Cleaning\source_data\Medicine_PackageSize.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    TABLOCK
);

SELECT COUNT(*) AS Medicine_PackageSize_Count FROM Medicine_PackageSize;
GO

-- ==========================
-- CREATE and LOAD Medicine_PackageContainer
--
-- Child table of Medicine — one row per container option.
-- Container_Size is the physical description
--   e.g. '100 ml bottle', '3 ml cartridge'.
-- Container_Size is NULL for Format B medicines —
--   those sold by unit price only with no physical
--   container description in the source data.
-- Unit_Price is the price per unit/container in BDT.
-- Unit_Price is NULL for 'Not for sale' and
--   'Price Unavailable' rows (~39 rows total) and
--   for µg pre-filled syringe rows (~3 rows).
-- ==========================
CREATE TABLE Medicine_PackageContainer (
    PackageContainer_ID  INT PRIMARY KEY,
    Brand_ID             INT NOT NULL,
    Container_Size       NVARCHAR(255),
    Unit_Price           DECIMAL(10,2),

    CONSTRAINT FK_PackageContainer_Medicine
        FOREIGN KEY (Brand_ID)
        REFERENCES Medicine(Brand_ID)
);

DROP TABLE IF EXISTS Staging_PackageContainer;

CREATE TABLE Staging_PackageContainer (
    PackageContainer_ID  INT,
    Brand_ID             INT,
    Container_Size       NVARCHAR(255),
    Unit_Price           NVARCHAR(50)
);

BULK INSERT Staging_PackageContainer
FROM 'E:\Data Analysis\My Projects\PharmaMarket_Cleaning\source_data\Medicine_PackageContainer.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    TABLOCK
);

-- Unit_Price uses TRY_CAST because NULL values export
-- as empty strings which cannot be cast directly to DECIMAL
INSERT INTO Medicine_PackageContainer (
    PackageContainer_ID, Brand_ID, Container_Size, Unit_Price
)
SELECT
    PackageContainer_ID,
    Brand_ID,
    Container_Size,
    TRY_CAST(TRY_CAST(Unit_Price AS FLOAT) AS DECIMAL(10,2))
FROM Staging_PackageContainer;

DROP TABLE Staging_PackageContainer;

SELECT COUNT(*) AS Medicine_PackageContainer_Count FROM Medicine_PackageContainer;
GO

-- ==========================
-- CREATE and LOAD Generic_Indication
-- ==========================
CREATE TABLE Generic_Indication (
    Generic_Indication_ID INT PRIMARY KEY,
    Generic_ID            INT NOT NULL,
    Indication_ID         INT NOT NULL,

    CONSTRAINT FK_GenericIndication_Generic
        FOREIGN KEY (Generic_ID)
        REFERENCES Generic(Generic_ID),

    CONSTRAINT FK_GenericIndication_Indication
        FOREIGN KEY (Indication_ID)
        REFERENCES Indication(Indication_ID),

    CONSTRAINT UQ_Generic_Indication
        UNIQUE (Generic_ID, Indication_ID)
);

BULK INSERT Generic_Indication
FROM 'E:\Data Analysis\My Projects\PharmaMarket_Cleaning\source_data\Generic_Indication.csv'
WITH (
    FIRSTROW = 2,
    FIELDTERMINATOR = ',',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    FORMAT = 'CSV',
    FIELDQUOTE = '"',
    TABLOCK
);

SELECT COUNT(*) AS Generic_Indication_Count FROM Generic_Indication;
GO

-- ==========================
-- FINAL ROW COUNT SUMMARY
-- ==========================
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
GO
