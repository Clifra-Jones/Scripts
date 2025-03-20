USE [master]
GO

GRANT VIEW SERVER STATE TO [zbx_monitor]
GRANT VIEW ANY DEFINITION TO [zbx_monitor]
GO

USE [msdb]
GO

GRANT SELECT ON OBJECT::msdb.dbo.sysjobs TO [zbx_monitor];
GRANT SELECT ON OBJECT::msdb.dbo.sysjobservers TO zbx_monitor;
GRANT SELECT ON OBJECT::msdb.dbo.sysjobactivity TO zbx_monitor;
GRANT EXECUTE ON OBJECT::msdb.dbo.agent_datetime TO zbx_monitor;
GO
