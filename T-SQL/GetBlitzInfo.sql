SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE or ALTER Procedure [dbo].[GetBlitzInfo]
(
    @StartTime DATETIME = NULL,
    @EndTime DATETIME = NULL,
    @DatabaseName VARCHAR(100) = NULL,
    @Stats VARCHAR(20) = NULL,
    @IncludeWaitCategories BIT = 0,
    @Help Bit = 0
)
AS

if @Help = 1
    BEGIN   
        PRINT N'This procedure returns date collected by the Fiorst Responder scrips saved into the database DBTools.'
        PRINT N'This data is collected every 15 minutes.'
        PRINT N''
        PRINT N'The following parameters are available:'
        PRINT N'@StartTime: The start Date and time to retrieve data. Date time in the format yyy/MM/dd HH:mm:ss'
        PRINT N'@EndTime: The start Date and time to retrieve data. Date time in the format yyy/MM/dd HH:mm:ss'
        PRINT N'@DatabaseName: The database name to retrieve data for.'
        PRINT N'@Stats: restict output to specific statistics.'
        Print N'  Accepted values are: BlitzFirst, BlitzCache, Blitz_FileStats, Blitz_WaitStats, & BlitzWho'
        PRINT N'  Omitting this will return all statustics.'
        PRINT N'@IncludeWaitCategories: Set to 1 to include the waut categories in the output.'
        PRINT N'@Help: Set to 1 to print this help'
        RETURN
    END

DECLARE @StartTimeOffset as DATETIMEOFFSET
DECLARE @EndTimeOffSet AS DATETIMEOFFSET
DECLARE @TmzOffSet AS VARCHAR(6)

IF @StartTime IS NULL
    Set @StartTime = DATEADD(MINUTE, -15, GETDATE())

IF @EndTime IS NULL
    Set @EndTime = GETDATE()

SELECT @TmzOffSet = FORMAT(SYSDATETIMEOFFSET(), 'zzz')
SELECT @StartTimeOffset = TODATETIMEOFFSET(@StartTime, @TmzOffSet)
Select @EndTimeOffSet = TODATETIMEOFFSET(@EndTime, @TmzOffSet)

Select @StartTimeOffset as StartTime, @EndTimeOffSet as EndTime

IF @DatabaseName IS NULL    
    BEGIN
        IF @Stats IS NULL
            BEGIN
                Select 'BlitzFirst' as [Stats], * From [dbo].[BlitzFirst]
                WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset
                ORDER BY [CHeckDate];

                SELECT 'BlitzCache' as [Stats], * From [dbo].[BlitzCache]
                WHERE [CheckDate] BETWEEN @StartTimeOffSet AND @EndTimeOffSet
                ORDER BY [CheckDate];

                Select 'Blitz_FileStats' AS [Stats], * From [dbo].[BlitzFirst_FileStats]
                WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset
                ORDER BY [CHeckDate];
            END
        ELSE
            BEGIN
                IF @Stats = 'BlitzFirst'
                    Select 'BlitzFirst' as [Stats], * From [dbo].[BlitzFirst]
                    WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset
                    ORDER BY [CHeckDate];
            
                ELSE IF @Stats = 'BlitzCache'   
                    Select 'BlitzCache' as [Stats], * From [dbo].[BlitzCache]
                    WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset
                    ORDER BY [CHeckDate];
                
                ELSE IF @Stats = 'Blitz_FileStats'
                    Select 'Blitz_FileStats' AS [Stats], * From [dbo].[BlitzFirst_FileStats]
                    WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset
                    ORDER BY [CHeckDate];
            END
    END
ELSE
    BEGIN
        IF @Stats IS NULL
            BEGIN
                Select 'BlitzFirst' as [Stats], * From [dbo].[BlitzFirst]
                WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset AND DatabaseName = @DatabaseName
                ORDER BY [CHeckDate];

                Select 'BlitzCache' as [Stats], * From [dbo].[BlitzCache]
                WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset AND DatabaseName = @DatabaseName
                ORDER BY [CHeckDate];

                Select 'Blitz_FileStats' AS [Stats], * From [dbo].[BlitzFirst_FileStats]
                WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset AND DatabaseName = @DatabaseName
                ORDER BY [CHeckDate];
            END
        ELSE 
            BEGIN 
                IF @Stats = 'BlitzFirst'
                    Select 'BlitzFirst' as [Stats], * From [dbo].[BlitzFirst]
                    WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset AND DatabaseName = @DatabaseName
                    ORDER BY [CHeckDate];
                
                ELSE IF @Stats = 'BlitzCache'   
                    Select 'BlitzCache' as [Stats], * From [dbo].[BlitzCache]
                    WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset AND DatabaseName = @DatabaseName
                    ORDER BY [CHeckDate];
                
                ELSE IF @Stats = 'Blitz_FileStats'
                    Select 'Blitz_FileStats' AS [Stats], * From [dbo].[BlitzFirst_FileStats]
                    WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset AND DatabaseName = @DatabaseName
                    ORDER BY [CHeckDate];
            END
    END

IF @Stats IS NULL
    BEGIN
        Select 'Blitz_WaitStats' as [Stats], * From [dbo].[BlitzFirst_WaitStats]
        WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset
        ORDER BY [CHeckDate];

        Select 'Blitz_PermonStats' AS [Stats], * From [dbo].[BlitzFirst_PerfmonStats]
        WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset
        ORDER BY [CHeckDate];

        Select 'BlitzWho' AS [Stats], * From [dbo].[BlitzWho]
        WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset
        ORDER BY [CHeckDate];
    END
ELSE
    BEGIN
        IF @Stats = 'Blitz_WaitStats'
            Select 'Blitz_WaitStats' as [Stats], * From [dbo].[BlitzFirst_WaitStats]
            WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset 
            ORDER BY [CHeckDate];

        ELSE IF @Stats = 'Blitz_PermonStats'
            Select 'Blitz_PermonStats' AS [Stats], * From [dbo].[BlitzFirst_PerfmonStats]
            WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset
            ORDER BY [CHeckDate];

        ELSE IF @Stats = 'BlitzWho'
            Select 'BlitzWho' AS [Stats], * From [dbo].[BlitzWho]
            WHERE [CheckDate] BETWEEN @StartTimeOffset AND @EndTimeOffset
            ORDER BY [CHeckDate];
    END

IF @IncludeWaitCategories = 1
    Select 'WaitStats_Categories' AS [Stats], * From [dbo].[BlitzFirst_WaitStats_Categories]

GO

