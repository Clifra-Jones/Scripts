-- Create a maintenance database if it doesn't exist
IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = 'DBA_Maintenance')
BEGIN
    CREATE DATABASE DBA_Maintenance;
END
GO

USE DBA_Maintenance;
GO

-- Create a table to store your templates
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'RoleTemplates')
BEGIN
    CREATE TABLE RoleTemplates (
        TemplateID INT IDENTITY(1,1) PRIMARY KEY,
        TemplateName NVARCHAR(100) NOT NULL UNIQUE,
        Description NVARCHAR(500),
        ScriptContent NVARCHAR(MAX) NOT NULL,
        IsActive BIT DEFAULT 1,
        CreatedBy NVARCHAR(128) DEFAULT SUSER_SNAME(),
        CreatedDate DATETIME DEFAULT GETDATE(),
        LastModifiedBy NVARCHAR(128) DEFAULT SUSER_SNAME(),
        LastModifiedDate DATETIME DEFAULT GETDATE()
    );
END
GO

CREATE OR ALTER PROCEDURE dbo.usp_ManageRoleTemplate
    @TemplateName NVARCHAR(100),
    @Description NVARCHAR(500),
    @ScriptContent NVARCHAR(MAX),
    @IsActive BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    IF EXISTS (SELECT 1 FROM RoleTemplates WHERE TemplateName = @TemplateName)
    BEGIN
        UPDATE RoleTemplates SET
            Description = @Description,
            ScriptContent = @ScriptContent,
            IsActive = @IsActive,
            LastModifiedBy = SUSER_SNAME(),
            LastModifiedDate = GETDATE()
        WHERE TemplateName = @TemplateName;
        
        PRINT 'Template updated successfully.';
    END
    ELSE
    BEGIN
        INSERT INTO RoleTemplates (TemplateName, Description, ScriptContent, IsActive)
        VALUES (@TemplateName, @Description, @ScriptContent, @IsActive);
        
        PRINT 'Template created successfully.';
    END
END
GO


CREATE OR ALTER PROCEDURE dbo.usp_ApplyRoleTemplate
    @TemplateName NVARCHAR(100),
    @DatabaseName NVARCHAR(128),
    @Parameters NVARCHAR(MAX) = NULL -- JSON format for additional parameters
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @ScriptContent NVARCHAR(MAX);
    DECLARE @SQL NVARCHAR(MAX);
    
    -- Get the template content
    SELECT @ScriptContent = ScriptContent
    FROM RoleTemplates
    WHERE TemplateName = @TemplateName AND IsActive = 1;
    
    IF @ScriptContent IS NULL
    BEGIN
        RAISERROR('Template not found or inactive', 16, 1);
        RETURN;
    END
    
    -- Replace parameters in the template
    SET @ScriptContent = REPLACE(@ScriptContent, '{{DatabaseName}}', @DatabaseName);
    
    -- Parse additional parameters if provided
    IF @Parameters IS NOT NULL
    BEGIN
        DECLARE @key NVARCHAR(128), @value NVARCHAR(MAX);
        
        DECLARE parameter_cursor CURSOR FOR
        SELECT [key], [value] FROM OPENJSON(@Parameters);
        
        OPEN parameter_cursor;
        FETCH NEXT FROM parameter_cursor INTO @key, @value;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            SET @ScriptContent = REPLACE(@ScriptContent, '{{' + @key + '}}', @value);
            FETCH NEXT FROM parameter_cursor INTO @key, @value;
        END
        
        CLOSE parameter_cursor;
        DEALLOCATE parameter_cursor;
    END
    
    -- Create the execution SQL
    SET @SQL = N'USE [' + @DatabaseName + N']; ' + @ScriptContent;
    
    -- Execute the SQL
    BEGIN TRY
        EXEC sp_executesql @SQL;
        PRINT 'Template applied successfully to database [' + @DatabaseName + ']';
    END TRY
    BEGIN CATCH
        PRINT 'Error applying template: ' + ERROR_MESSAGE();
    END CATCH
END
GO

GRANT EXECUTE ON dbo.usp_ApplyRoleTemplate TO PUBLIC;
GO


CREATE OR ALTER TRIGGER [StandardizeNewDatabases]
ON ALL SERVER
FOR CREATE_DATABASE
AS
BEGIN
    DECLARE @dbname NVARCHAR(128);
    DECLARE @params NVARCHAR(MAX);
    DECLARE @isDatabaseManager BIT = 0;
    DECLARE @loginName NVARCHAR(128);
    
    -- Get the name of the newly created database and the login who created it
    SELECT 
        @dbname = EVENTDATA().value('(/EVENT_INSTANCE/DatabaseName)[1]', 'nvarchar(128)'),
        @loginName = EVENTDATA().value('(/EVENT_INSTANCE/LoginName)[1]', 'nvarchar(128)');
    
    -- Check if the login is a member of the ##MS_DatabaseManagers## role
    -- This approach will work if the user is authenticating via Windows Authentication
    -- and is a member of the AD group that's added to the server role
    IF IS_SRVROLEMEMBER('##MS_DatabaseManagers##', @loginName) = 1
    BEGIN
        SET @isDatabaseManager = 1;
    END
    
    -- Define which login should have full schema control privileges
    -- In this case, we'll use 'sa' as the admin login that bypasses restrictions
    DECLARE @adminLogin NVARCHAR(128) = 'sa';

    -- Set parameters including the flag for Database Manager membership
    SET @params = N'{
        "AdminLogin": "' + REPLACE(@loginName, '''', '''''') + '",
        "IsDatabaseManagerMember": ' + CAST(@isDatabaseManager AS NVARCHAR(1)) + '
    }';
    
    -- Apply the template
    EXEC DBA_Maintenance.dbo.usp_ApplyRoleTemplate
        @TemplateName = 'StandardDBRoles',
        @DatabaseName = @dbname,
        @Parameters = @params;
END;

