-- Update your main template to remove the trigger
DECLARE @StandardDBRoleScript NVARCHAR(MAX) = N'

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = ''DB_PermissionManager'' AND type = ''R'')
BEGIN
    CREATE ROLE [DB_PermissionManager];
    GRANT ALTER ANY USER TO [DB_PermissionManager];
    GRANT ALTER ANY ROLE TO [DB_PermissionManager];
END;

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = ''BBC\SQLServer_Database_Managers'')
BEGIN
    CREATE USER [BBC\SQLServer_Database_Managers] FOR LOGIN [BBC\SQLServer_Database_Managers];
    ALTER ROLE [DB_PermissionManager] ADD MEMBER [BBC\SQLServer_Database_Managers];
END;

IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = ''db_admin_custom'' AND type = ''R'')
BEGIN
    CREATE ROLE [db_admin_custom];
    
    GRANT ALTER ON DATABASE::[{{DatabaseName}}] TO [db_admin_custom];
    GRANT CONTROL ON DATABASE::[{{DatabaseName}}] TO [db_admin_custom];
    GRANT CREATE TABLE TO [db_admin_custom];
    GRANT CREATE VIEW TO [db_admin_custom];
    GRANT CREATE PROCEDURE TO [db_admin_custom];
    GRANT CREATE FUNCTION TO [db_admin_custom];
    GRANT EXECUTE TO [db_admin_custom];
    GRANT SELECT TO [db_admin_custom];
    GRANT INSERT TO [db_admin_custom];
    GRANT UPDATE TO [db_admin_custom];
    GRANT DELETE TO [db_admin_custom];
END;

PRINT ''Custom admin role created in database [{{DatabaseName}}]'';
';

EXEC dbo.usp_ManageRoleTemplate
    @TemplateName = 'StandardDBRoles',
    @Description = 'Default template for standard database roles and permissions',
    @ScriptContent = @StandardDBRoleScript,
    @IsActive = 1;


DECLARE @TriggerTemplate NVARCHAR(MAX) = N'
CREATE OR ALTER TRIGGER prevent_schema_creation
ON DATABASE 
FOR CREATE_SCHEMA, ALTER_SCHEMA, DROP_SCHEMA
AS
BEGIN
    IF NOT (IS_MEMBER(''db_owner'') = 1 OR ORIGINAL_LOGIN() = ''{{AdminLogin}}'')
    BEGIN
        PRINT ''You do not have permission to create or modify schemas.'';
        ROLLBACK;
    END
END;
';

EXEC dbo.usp_ManageRoleTemplate
    @TemplateName = 'SchemaCreationTrigger',
    @Description = 'Trigger to prevent unauthorized schema creation',
    @ScriptContent = @TriggerTemplate,
    @IsActive = 1;
