CREATE OR ALTER TRIGGER [tr_DatabaseCreation_SetupRoles] 
ON ALL SERVER 
FOR CREATE_DATABASE 
AS
BEGIN
    SET NOCOUNT ON;
    
    -- Get the name of the database that was just created
    DECLARE @dbName NVARCHAR(128)
    SET @dbName = EVENTDATA().value('(/EVENT_INSTANCE/DatabaseName)[1]', 'nvarchar(128)')
    
    -- Get the login of the person who created the database (for logging only)
    DECLARE @loginName NVARCHAR(128)
    SET @loginName = EVENTDATA().value('(/EVENT_INSTANCE/LoginName)[1]', 'nvarchar(128)')
    
    -- All operations need to be in a single EXEC to maintain database context
    DECLARE @sql NVARCHAR(MAX)
    SET @sql = N'USE [' + @dbName + '];
    
    -- Create the role if it doesn''t exist
    IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = ''DB_PermissionManager'' AND type = ''R'')
    BEGIN
        CREATE ROLE [DB_PermissionManager];
        GRANT ALTER ANY USER TO [DB_PermissionManager];
        GRANT ALTER ANY ROLE TO [DB_PermissionManager];
    END;
    
    -- Create user for the AD group and add to role
    IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = ''domain\SQLServer_Database_Managers'')
    BEGIN
        CREATE USER [domain\SQLServer_Database_Managers] FOR LOGIN [domain\SQLServer_Database_Managers];
        ALTER ROLE [DB_PermissionManager] ADD MEMBER [domain\SQLServer_Database_Managers];
    END;
    
    -- Create custom admin role
    IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = ''db_admin_custom'' AND type = ''R'')
    BEGIN
        CREATE ROLE [db_admin_custom];
        
        -- Grant necessary permissions to the role
        GRANT ALTER ON DATABASE::[' + @dbname + N'] TO [db_admin_custom];
        GRANT CONTROL ON DATABASE::[' + @dbname + N'] TO [db_admin_custom];
        GRANT CREATE TABLE TO [db_admin_custom];
        GRANT CREATE VIEW TO [db_admin_custom];
        GRANT CREATE PROCEDURE TO [db_admin_custom];
        GRANT CREATE FUNCTION TO [db_admin_custom];
        GRANT EXECUTE TO [db_admin_custom];
        GRANT SELECT TO [db_admin_custom];
        GRANT INSERT TO [db_admin_custom];
        GRANT UPDATE TO [db_admin_custom];
        GRANT DELETE TO [db_admin_custom];'
    
    EXEC sp_executesql @sql;


    
    -- Log the database creation for later ownership transfer
    INSERT INTO master.dbo.DatabaseOwnershipTransfers (DatabaseName, CreatedBy)
    VALUES (@dbName, @loginName)
END
GO