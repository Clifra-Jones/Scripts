DECLARE @TableName as NVARCHAR(128) = 'tablename'
Declare @MaxLength as INT = 128

SELECT 'ALTER TABLE @TanbleName ALTER COLUMN ' + c.name + ' varchar(128);'
FROM sys.columns c
JOIN sys.tables t ON c.object_id = t.object_id
JOIN sys.types ty ON c.user_type_id = ty.user_type_id
Where t.name = 'MDA_PBCS_Entity_Import_Stage'
AND ty.name = 'varchar'
AND c.max_length = -1
