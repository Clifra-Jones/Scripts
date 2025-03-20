USE [DESTINIData_California]
GO

DROP USER [BIReportUser]
GO

CREATE USER [BIReportUser] FOR LOGIN [BIReportUser] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [BIReportUser]
GO

USE [DESTINIData_Charlotte]
GO

DROP USER [BIReportUser]
GO

CREATE USER [BIReportUser] FOR LOGIN [BIReportUser] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [BIReportUser]
GO

USE [DESTINIData_Charlotte]
GO

DROP USER [BIReportUser]
GO

CREATE USER [BIReportUser] FOR LOGIN [BIReportUser] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [BIReportUser]
GO

USE [DESTINIData_Florida]
GO

DROP USER [BIReportUser]
GO

CREATE USER [BIReportUser] FOR LOGIN [BIReportUser] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [BIReportUser]
GO

USE [DESTINIData_Raleigh]
GO

DROP USER [BIReportUser]
GO

CREATE USER [BIReportUser] FOR LOGIN [BIReportUser] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [BIReportUser]
GO

USE [DESTINIData_Texas]
GO

DROP USER [BIReportUser]
GO

CREATE USER [BIReportUser] FOR LOGIN [BIReportUser] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [BIReportUser]
GO

USE [DestiniData_DC]
GO

DROP USER [BIReportUser]
GO

CREATE USER [BIReportUser] FOR LOGIN [BIReportUser] WITH DEFAULT_SCHEMA=[dbo]
GO
ALTER ROLE [db_datareader] ADD MEMBER [BIReportUser]
GO

