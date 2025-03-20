CREATE OR ALTER PROCEDURE dbo.sp_CreateSQLServerJob
    @JobName NVARCHAR(128),
    @JobDescription NVARCHAR(512) = NULL,
    @JobCategory NVARCHAR(128) = N'[Uncategorized (Local)]',
    @StepName NVARCHAR(128),
    @StepCommand NVARCHAR(MAX),
    @StepSubsystem NVARCHAR(40) = N'TSQL',
    @StepDatabase NVARCHAR(128) = N'master',
    @ScheduleName NVARCHAR(128) = NULL,
    @Frequency NVARCHAR(20) = 'DAILY',  -- Options: ONCE, DAILY, WEEKLY, MONTHLY, MONTHLY_RELATIVE, AT_STARTUP
    @Interval NVARCHAR(50) = '1',       -- For DAILY: number of days; For WEEKLY: 'MON,TUE,WED,THU,FRI,SAT,SUN'; For MONTHLY: day of month (1-31)
    @StartTime NVARCHAR(8) = '01:00',   -- Format: 'HH:MM' in 24-hour format
    @Owner NVARCHAR(128) = NULL,
    @Enabled BIT = 1
AS
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @JobID UNIQUEIDENTIFIER;
    DECLARE @ReturnCode INT = 0;
    DECLARE @FrequencyType INT;
    DECLARE @FrequencyInterval INT = 0;
    DECLARE @StartTimeInt INT;
    
    -- Set default owner if not specified
    IF @Owner IS NULL
    BEGIN
        SET @Owner = SUSER_SNAME();
    END
    
    -- Set default schedule name if not specified
    IF @ScheduleName IS NULL
    BEGIN
        SET @ScheduleName = @JobName + N'_Schedule';
    END
    
    -- Convert frequency from string to numeric type
    SET @Frequency = UPPER(@Frequency);
    SET @FrequencyType = 
        CASE @Frequency
            WHEN 'ONCE' THEN 1
            WHEN 'DAILY' THEN 4
            WHEN 'WEEKLY' THEN 8
            WHEN 'MONTHLY' THEN 16
            WHEN 'MONTHLY_RELATIVE' THEN 32
            WHEN 'AT_STARTUP' THEN 64
            ELSE 4 -- Default to daily
        END;
    
    -- Convert interval based on frequency type
    IF @FrequencyType = 4 -- DAILY
    BEGIN
        SET @FrequencyInterval = TRY_CAST(@Interval AS INT);
        IF @FrequencyInterval IS NULL OR @FrequencyInterval < 1
            SET @FrequencyInterval = 1;
    END
    ELSE IF @FrequencyType = 8 -- WEEKLY
    BEGIN
        -- For weekly, parse days: 'MON,TUE,WED' etc.
        SET @FrequencyInterval = 0;
        
        IF @Interval LIKE '%MON%' SET @FrequencyInterval = @FrequencyInterval + 2;
        IF @Interval LIKE '%TUE%' SET @FrequencyInterval = @FrequencyInterval + 4;
        IF @Interval LIKE '%WED%' SET @FrequencyInterval = @FrequencyInterval + 8;
        IF @Interval LIKE '%THU%' SET @FrequencyInterval = @FrequencyInterval + 16;
        IF @Interval LIKE '%FRI%' SET @FrequencyInterval = @FrequencyInterval + 32;
        IF @Interval LIKE '%SAT%' SET @FrequencyInterval = @FrequencyInterval + 64;
        IF @Interval LIKE '%SUN%' SET @FrequencyInterval = @FrequencyInterval + 1;
        
        -- If no valid days specified, default to Monday
        IF @FrequencyInterval = 0 SET @FrequencyInterval = 2;
    END
    ELSE IF @FrequencyType = 16 -- MONTHLY
    BEGIN
        SET @FrequencyInterval = TRY_CAST(@Interval AS INT);
        IF @FrequencyInterval IS NULL OR @FrequencyInterval < 1 OR @FrequencyInterval > 31
            SET @FrequencyInterval = 1;
    END
    ELSE IF @FrequencyType = 32 -- MONTHLY_RELATIVE
    BEGIN
        -- Convert text like 'FIRST MONDAY' to the appropriate code
        DECLARE @Position NVARCHAR(20);
        DECLARE @Weekday NVARCHAR(20);
        
        -- Extract position (FIRST, SECOND, etc.)
        SET @Position = 
            CASE 
                WHEN @Interval LIKE 'FIRST%' THEN 'FIRST'
                WHEN @Interval LIKE 'SECOND%' THEN 'SECOND'
                WHEN @Interval LIKE 'THIRD%' THEN 'THIRD'
                WHEN @Interval LIKE 'FOURTH%' THEN 'FOURTH'
                WHEN @Interval LIKE 'LAST%' THEN 'LAST'
                ELSE 'FIRST' -- Default
            END;
            
        -- Extract weekday (MONDAY, TUESDAY, etc.)
        SET @Weekday = 
            CASE 
                WHEN @Interval LIKE '%MONDAY%' THEN 'MONDAY'
                WHEN @Interval LIKE '%TUESDAY%' THEN 'TUESDAY'
                WHEN @Interval LIKE '%WEDNESDAY%' THEN 'WEDNESDAY'
                WHEN @Interval LIKE '%THURSDAY%' THEN 'THURSDAY'
                WHEN @Interval LIKE '%FRIDAY%' THEN 'FRIDAY'
                WHEN @Interval LIKE '%SATURDAY%' THEN 'SATURDAY'
                WHEN @Interval LIKE '%SUNDAY%' THEN 'SUNDAY'
                WHEN @Interval LIKE '%DAY%' THEN 'DAY'
                WHEN @Interval LIKE '%WEEKDAY%' THEN 'WEEKDAY'
                WHEN @Interval LIKE '%WEEKEND%' THEN 'WEEKEND'
                ELSE 'DAY' -- Default
            END;
            
        -- Calculate frequency interval value
        DECLARE @PositionValue INT = 
            CASE @Position
                WHEN 'FIRST' THEN 1
                WHEN 'SECOND' THEN 2
                WHEN 'THIRD' THEN 3
                WHEN 'FOURTH' THEN 4
                WHEN 'LAST' THEN 5
                ELSE 1
            END;
            
        DECLARE @WeekdayValue INT = 
            CASE @Weekday
                WHEN 'SUNDAY' THEN 1
                WHEN 'MONDAY' THEN 2
                WHEN 'TUESDAY' THEN 3
                WHEN 'WEDNESDAY' THEN 4
                WHEN 'THURSDAY' THEN 5
                WHEN 'FRIDAY' THEN 6
                WHEN 'SATURDAY' THEN 7
                WHEN 'DAY' THEN 8
                WHEN 'WEEKDAY' THEN 9
                WHEN 'WEEKEND' THEN 10
                ELSE 8
            END;
            
        SET @FrequencyInterval = @WeekdayValue;
    END
    ELSE -- ONCE or AT_STARTUP
    BEGIN
        SET @FrequencyInterval = 1;
    END
    
    -- Convert time from HH:MM format to HHMMSS integer
    DECLARE @Hours INT, @Minutes INT;
    
    -- Check if time is in valid format (HH:MM)
    IF @StartTime LIKE '__%:%__' 
    BEGIN
        SET @Hours = TRY_CAST(SUBSTRING(@StartTime, 1, 2) AS INT);
        SET @Minutes = TRY_CAST(SUBSTRING(@StartTime, 4, 2) AS INT);
        
        -- Validate hours and minutes
        IF @Hours IS NULL OR @Hours < 0 OR @Hours > 23 SET @Hours = 1;
        IF @Minutes IS NULL OR @Minutes < 0 OR @Minutes > 59 SET @Minutes = 0;
        
        SET @StartTimeInt = (@Hours * 10000) + (@Minutes * 100);
    END
    ELSE
    BEGIN
        -- Default to 01:00 AM
        SET @StartTimeInt = 10000;
    END
    
    -- Check if MSDB is accessible and SQL Agent is running
    IF NOT EXISTS (SELECT 1 FROM sys.databases WHERE name = 'msdb')
    BEGIN
        RAISERROR('MSDB database is not accessible.', 16, 1);
        RETURN -1;
    END
    
    IF NOT EXISTS (SELECT 1 FROM msdb.dbo.syssubsystems WHERE subsystem IN ('TSQL', 'PowerShell', 'CmdExec'))
    BEGIN
        RAISERROR('SQL Server Agent may not be running or accessible.', 16, 1);
        RETURN -2;
    END
    
    -- Check if job already exists
    IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
    BEGIN
        RAISERROR('A job with name "%s" already exists.', 16, 1, @JobName);
        RETURN -3;
    END
    
    BEGIN TRY
        BEGIN TRANSACTION;
        
        -- Create the job
        EXEC @ReturnCode = msdb.dbo.sp_add_job 
            @job_name = @JobName,
            @description = @JobDescription,
            @category_name = @JobCategory,
            @owner_login_name = @Owner,
            @enabled = @Enabled,
            @job_id = @JobID OUTPUT;
            
        IF @ReturnCode <> 0 OR @JobID IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('Failed to create job.', 16, 1);
            RETURN -4;
        END
        
        -- Add the job step
        EXEC @ReturnCode = msdb.dbo.sp_add_jobstep
            @job_id = @JobID,
            @step_name = @StepName,
            @step_id = 1,
            @subsystem = @StepSubsystem,
            @command = @StepCommand,
            @database_name = @StepDatabase,
            @on_success_action = 1,  -- Quit with success
            @on_fail_action = 2;     -- Quit with failure
            
        IF @ReturnCode <> 0
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('Failed to create job step.', 16, 1);
            RETURN -5;
        END
        
        -- Add the schedule
        DECLARE @ScheduleID INT;
        
        EXEC @ReturnCode = msdb.dbo.sp_add_schedule
            @schedule_name = @ScheduleName,
            @freq_type = @FrequencyType,
            @freq_interval = @FrequencyInterval,
            @active_start_time = @StartTimeInt,
            @schedule_id = @ScheduleID OUTPUT,
            @enabled = @Enabled;
            
        IF @ReturnCode <> 0 OR @ScheduleID IS NULL
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('Failed to create schedule.', 16, 1);
            RETURN -6;
        END
        
        -- Attach the schedule to the job
        EXEC @ReturnCode = msdb.dbo.sp_attach_schedule
            @job_id = @JobID,
            @schedule_id = @ScheduleID;
            
        IF @ReturnCode <> 0
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('Failed to attach schedule to job.', 16, 1);
            RETURN -7;
        END
        
        -- Add the server
        EXEC @ReturnCode = msdb.dbo.sp_add_jobserver
            @job_id = @JobID,
            @server_name = N'(local)';
            
        IF @ReturnCode <> 0
        BEGIN
            ROLLBACK TRANSACTION;
            RAISERROR('Failed to add job server.', 16, 1);
            RETURN -8;
        END
        
        COMMIT TRANSACTION;
        
        -- Return descriptive information about the created job
        DECLARE @FrequencyDesc NVARCHAR(100) = 
            CASE @FrequencyType
                WHEN 1 THEN 'Once'
                WHEN 4 THEN 'Every ' + CAST(@FrequencyInterval AS NVARCHAR) + ' day(s)'
                WHEN 8 THEN 'Weekly on ' + 
                    STUFF(
                        CASE WHEN @FrequencyInterval & 1 > 0 THEN ', Sunday' ELSE '' END +
                        CASE WHEN @FrequencyInterval & 2 > 0 THEN ', Monday' ELSE '' END +
                        CASE WHEN @FrequencyInterval & 4 > 0 THEN ', Tuesday' ELSE '' END +
                        CASE WHEN @FrequencyInterval & 8 > 0 THEN ', Wednesday' ELSE '' END +
                        CASE WHEN @FrequencyInterval & 16 > 0 THEN ', Thursday' ELSE '' END +
                        CASE WHEN @FrequencyInterval & 32 > 0 THEN ', Friday' ELSE '' END +
                        CASE WHEN @FrequencyInterval & 64 > 0 THEN ', Saturday' ELSE '' END, 1, 2, '')
                WHEN 16 THEN 'Monthly on day ' + CAST(@FrequencyInterval AS NVARCHAR)
                WHEN 32 THEN 'Monthly on ' + 
                    CASE @PositionValue
                        WHEN 1 THEN 'first '
                        WHEN 2 THEN 'second '
                        WHEN 3 THEN 'third '
                        WHEN 4 THEN 'fourth '
                        WHEN 5 THEN 'last '
                        ELSE ''
                    END +
                    CASE @WeekdayValue
                        WHEN 1 THEN 'Sunday'
                        WHEN 2 THEN 'Monday'
                        WHEN 3 THEN 'Tuesday'
                        WHEN 4 THEN 'Wednesday'
                        WHEN 5 THEN 'Thursday'
                        WHEN 6 THEN 'Friday'
                        WHEN 7 THEN 'Saturday'
                        WHEN 8 THEN 'day'
                        WHEN 9 THEN 'weekday'
                        WHEN 10 THEN 'weekend day'
                        ELSE 'day'
                    END
                WHEN 64 THEN 'When SQL Server Agent starts'
                ELSE 'Unknown schedule type'
            END;
            
        DECLARE @TimeDesc NVARCHAR(50) = 
            CASE 
                WHEN @FrequencyType IN (1, 4, 8, 16, 32) THEN 
                    SUBSTRING(CAST(@StartTimeInt + 1000000 AS NVARCHAR), 3, 2) + ':' + 
                    SUBSTRING(CAST(@StartTimeInt + 1000000 AS NVARCHAR), 5, 2)
                ELSE ''
            END;
            
        SELECT 
            'Job created successfully' AS Result,
            @JobName AS JobName,
            @JobID AS JobID,
            @FrequencyDesc + 
                CASE WHEN @TimeDesc <> '' THEN ' at ' + @TimeDesc ELSE '' END AS ScheduleDescription;
            
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
            
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        DECLARE @ErrorSeverity INT = ERROR_SEVERITY();
        DECLARE @ErrorState INT = ERROR_STATE();
        
        RAISERROR(@ErrorMessage, @ErrorSeverity, @ErrorState);
        RETURN -100;
    END CATCH
    
    RETURN 0;
END;
GO