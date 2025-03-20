IF OBJECT_ID(N'tempdb..#extProps') IS NOT NULL DROP TABLE #extProps

CREATE TABLE #extProps (
    dbname NVARCHAR(1000),
    class_desc sql_variant,
    [name] sql_variant,
    [value] sql_variant
)

Declare @sql NVARCHAR(max)

Select @sql = (
    SELECT 'USE' +QUOTENAME([NAME])+ ' INSERT INTO #extProps SELECT ''' +[name] + ''' as dbname, class_desc, [name], [value] FROM sys.extended_properties;' +CHAR(10)
    FROM sys.databases
    FOR XML PATH('')
)

--Print @sql

EXEC sp_executeSQL @sql

SELECT * FROM #extProps