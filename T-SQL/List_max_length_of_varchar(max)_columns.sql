DECLARE @tableName NVARCHAR(128) = 'tablename';
DECLARE @sql NVARCHAR(MAX);

-- Build dynamic SQL to find max length for each VARCHAR(MAX) column
SET @sql = 
(
    SELECT STUFF(
        (
            SELECT ' UNION ALL SELECT ''' + c.name + ''' AS column_name, MAX(LEN(' + QUOTENAME(c.name) + ')) AS max_length FROM ' + QUOTENAME(@tableName)
            FROM sys.columns c
            JOIN sys.tables t ON c.object_id = t.object_id
            JOIN sys.types ty ON c.user_type_id = ty.user_type_id
            WHERE t.name = @tableName
            AND ty.name = 'varchar'
            AND c.max_length = -1 -- This identifies VARCHAR(MAX) columns
            FOR XML PATH(''), TYPE
        ).value('.', 'NVARCHAR(MAX)'), 1, 11, ''
    )
);

-- Add final order by to get the longest entry at the top
SET @sql = 'WITH MaxLengths AS (' + @sql + ') SELECT * FROM MaxLengths ORDER BY max_length DESC;';

-- Execute the dynamic SQL
EXEC sp_executesql @sql;