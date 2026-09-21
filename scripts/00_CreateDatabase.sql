-- =================================================
-- 00_CreateDatabase.sql
-- Creates the configured cleaning database
-- Run this script first before any other scripts
-- =================================================

-- ==========================
-- CREATE DATABASE IF NOT EXISTS
-- ==========================
IF '$(DatabaseName)' = '$' + '(DatabaseName)'
    THROW 50000, 'DatabaseName SQLCMD variable is required.', 1;

DECLARE @DatabaseName sysname = N'$(DatabaseName)';
DECLARE @CreateSql nvarchar(max);

IF DB_ID(@DatabaseName) IS NULL
BEGIN
    SET @CreateSql = N'CREATE DATABASE ' + QUOTENAME(@DatabaseName) + N';';
    EXEC sys.sp_executesql @CreateSql;
    PRINT N'Database ' + QUOTENAME(@DatabaseName) + N' created successfully.';
END
ELSE
BEGIN
    PRINT N'Database ' + QUOTENAME(@DatabaseName) + N' already exists.';
END
GO

-- ==========================
-- SET CONTEXT TO DATABASE
-- ==========================
USE [$(DatabaseName)];
GO

-- ==========================
-- NOTE:
-- All subsequent scripts assume this database context.
-- Run this script first to ensure a clean and consistent environment.
-- If rebuilding from scratch, run 02_LoadSourceData.sql after this.
-- =================================================
