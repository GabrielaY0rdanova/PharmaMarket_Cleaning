-- =================================================
-- 00_CreateDatabase.sql
-- Creates the PharmaMarketAnalytics_Clean database
-- Run this script first before any other scripts
-- =================================================

-- ==========================
-- CREATE DATABASE IF NOT EXISTS
-- ==========================
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'PharmaMarketAnalytics_Clean')
BEGIN
    CREATE DATABASE PharmaMarketAnalytics_Clean;
    PRINT 'Database PharmaMarketAnalytics_Clean created successfully.';
END
ELSE
BEGIN
    PRINT 'Database PharmaMarketAnalytics_Clean already exists.';
END
GO

-- ==========================
-- SET CONTEXT TO DATABASE
-- ==========================
USE PharmaMarketAnalytics_Clean;
GO

-- ==========================
-- NOTE:
-- All subsequent scripts assume this database context.
-- Run this script first to ensure a clean and consistent environment.
-- If rebuilding from scratch, run 02_LoadSourceData.sql after this.
-- =================================================