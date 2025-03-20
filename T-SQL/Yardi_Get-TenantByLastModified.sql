-- Daily backup job at 1:00 AM
EXEC dbo.sp_CreateSQLServerJob
    @JobName = 'Daily_Full_Backup',
    @JobDescription = 'Performs a full backup daily',
    @StepName = 'Run Backup',
    @StepCommand = 'BACKUP DATABASE [YourDB] TO DISK = N''/var/opt/mssql/backup/YourDB_$(date).bak'' WITH INIT, STATS = 10',
    @StepDatabase = 'master',
    @Frequency = 'DAILY',
    @Interval = '1',
    @StartTime = '01:00';

-- Weekly job on Mondays, Wednesdays, and Fridays at 2:30 AM
EXEC dbo.sp_CreateSQLServerJob
    @JobName = 'Weekly_Maintenance',
    @JobDescription = 'Weekly index maintenance',
    @JobCategory = 'Database Maintenance',
    @StepName = 'Rebuild Indexes',
    @StepCommand = 'EXEC dbo.sp_RebuildIndexes',
    @StepDatabase = 'YourDB',
    @Frequency = 'WEEKLY',
    @Interval = 'MON,WED,FRI',
    @StartTime = '02:30';

-- Monthly job on the 15th at 23:00 (11:00 PM)
EXEC dbo.sp_CreateSQLServerJob
    @JobName = 'Monthly_Reporting',
    @JobDescription = 'Generate monthly reports',
    @StepName = 'Run Reporting Procedure',
    @StepCommand = 'EXEC dbo.sp_GenerateMonthlyReport',
    @Frequency = 'MONTHLY',
    @Interval = '15',
    @StartTime = '23:00';

-- Monthly job on the last Friday at 18:00 (6:00 PM)
EXEC dbo.sp_CreateSQLServerJob
    @JobName = 'Month_End_Processing',
    @JobDescription = 'Month-end data processing',
    @StepName = 'Process Month End',
    @StepCommand = 'EXEC dbo.sp_MonthEndProcess',
    @Frequency = 'MONTHLY_RELATIVE',
    @Interval = 'LAST FRIDAY',
    @StartTime = '18:00';

-- Job that runs when SQL Server Agent starts
EXEC dbo.sp_CreateSQLServerJob
    @JobName = 'Startup_Cleanup',
    @JobDescription = 'Cleanup temp files at startup',
    @StepName = 'Cleanup Temp Files',
    @StepCommand = 'EXEC dbo.sp_CleanupTempFiles',
    @Frequency = 'AT_STARTUP';