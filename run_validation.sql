:setvar DatabaseName "PharmaMarketAnalytics_Clean_Test"
:on error exit

PRINT N'Validating database: $(DatabaseName)';
GO

:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\tests\12_Validation.sql"
:r "E:\Data Analysis\My Projects\PharmaMarket Data Platform\PharmaMarket_Cleaning\tests\13_ValidationGate.sql"

PRINT N'Validation finished for $(DatabaseName).';
GO
