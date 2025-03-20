USE [msdb]
GO

-- Create the job
DECLARE @jobId BINARY(16)
EXEC msdb.dbo.sp_add_job 
    @job_name = N'Transfer Database Ownership to SA', 
    @enabled = 1, 
    @description = N'Transfers ownership of newly created databases to SA account after 24 hours', 
    @category_name = N'Database Maintenance',
    @owner_login_name = N'sa',
    @job_id = @jobId OUTPUT

-- Create the job step
EXEC msdb.dbo.sp_add_jobstep 
    @job_id = @jobId, 
    @step_name = N'Process Ownership Transfers', 
    @step_id = 1, 
    @cmdexec_success_code = 0, 
    @on_success_action = 1,  -- Quit with success
    @on_fail_action = 2,     -- Quit with failure
    @retry_attempts = 0, 
    @retry_interval = 0, 
    @os_run_priority = 0,
    @subsystem = N'TSQL', 
    @command = N'EXEC sp_UpdateNewDatabaseOwner', 
    @database_name = N'master', 
    @flags = 0

-- Create the schedule (daily at 2:00 AM)
EXEC msdb.dbo.sp_add_jobschedule 
    @job_id = @jobId, 
    @name = N'Daily_2AM', 
    @enabled = 1, 
    @freq_type = 4,          -- Daily
    @freq_interval = 1,      -- Every day
    @freq_subday_type = 1,   -- At the specified time
    @freq_subday_interval = 0, 
    @freq_relative_interval = 0, 
    @freq_recurrence_factor = 0, 
    @active_start_date = 20220101,  -- Start date (you can adjust this)
    @active_end_date = 99991231,    -- End date (far in the future)
    @active_start_time = 20000,     -- 2:00:00 AM
    @active_end_time = 235959       -- 11:59:59 PM

-- Assign the job to the SQL Server instance (local)
EXEC msdb.dbo.sp_add_jobserver 
    @job_id = @jobId, 
    @server_name = N'(local)'
GO