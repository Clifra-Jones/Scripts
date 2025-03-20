SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
-- =============================================
-- Author:		Cliff Williams
-- Create date: 07-18-2024
-- Description:	Update tthe tbl_TOTAL tabe from Yardi
-- =============================================
CREATE PROCEDURE [dbo].[Update_TOTAL] 
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @CurrentDate date;
    Declare @SQL nvarchar(500);

    SET @CurrentDate = CAST( GETDATE() as date);

    SET @SQL = 'SELECT [HPPTY],[UMONTH],[IBOOK],[HACCT],[SBEGIN],[SMTD],[SBEGINBUDGET],[SBUDGET]
                INTO #tmp_TOTAL
                FROM OPENQUERY(
                    [YARDISQL.BBC.LOCAL],
                    ''Select * from [olqksit_live].[dbo].[TENANT] where dtLastModified > ''''' + CONVERT(nvarchar(30), @CurrentDate) + ''''''')'
    
    Exec (@SQL)

    MERGE INTO [dbo].[tbl_TOTAL] AS T
        USING #tmp_TOTAL AS S
        ON (T.HPPTY = S.HPPTY)
        WHEN MATCHED THEN
            UPDATE 
                Set T.UMONTH = S.UNOMTH,
                    T.IBOOK = S.IBOOK,
                    T.HACCT = S.HACCT,
                    T.SBEGIN = S.SBEGIN,
                    T.SMTD = S.SMTD,
                    T.SBEGINBUDGET = S.SBEGINBUDGET,
                    T.SBUDGET = S.SBUDGET
        WHEN NOT MATCHED BY TARGET THEN
            INSERT ([HPPTY],[UMONTH],[IBOOK],[HACCT],[SBEGIN],[SMTD],[SBEGINBUDGET],[SBUDGET])
            VALUES ([S.HPPTY],[S.UMONTH],[S.IBOOK],[S.HACCT],[S.SBEGIN],[S.SMTD],[S.SBEGINBUDGET],[S.SBUDGET]);

END