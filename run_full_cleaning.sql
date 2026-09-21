:setvar DatabaseName "PharmaMarketAnalytics_Clean_Test"
:setvar AllowDestructiveReset "YES"
:setvar SourceDataPath "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\source_data"
:on error exit

PRINT N'Target database: $(DatabaseName)';
PRINT N'Source snapshot: $(SourceDataPath)';
GO

:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\00_CreateDatabase.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\02_LoadSourceData.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\03_DrugClass_Cleaning.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\04_DosageForm_Cleaning.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\05_Manufacturer_Cleaning.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\06_Indication_Cleaning.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\07_Generic_Cleaning.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\08_Medicine_Cleaning.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\09_MedicinePackageSize_Cleaning.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\10_MedicinePackageContainer_Cleaning.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\scripts\11_GenericIndication_Cleaning.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\tests\12_Validation.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\tests\13_ValidationGate.sql"

PRINT N'Complete cleaning rebuild and validation finished for $(DatabaseName).';
GO
