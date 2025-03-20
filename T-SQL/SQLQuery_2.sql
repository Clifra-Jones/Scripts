SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[sp_TransferDatabaseOwnershipToSA]
    @databaseName NVARCHAR(128)
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @sql NVARCHAR(MAX)
    SET @sql = N'USE [' + @databaseName + '];
    ALTER AUTHORIZATION ON DATABASE::[' + @databaseName + '] TO [sa]'
    
    EXEC sp_executesql @sql
    
    PRINT 'Ownership of database [' + @databaseName + '] transferred to [sa].'
END
GO
