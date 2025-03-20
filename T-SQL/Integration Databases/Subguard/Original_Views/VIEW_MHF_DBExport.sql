SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER VIEW [dbo].[VIEW_MHF_DBExport]
AS
(
        SELECT TOP 10 k.*,
            U.SingleAmt,
            U.aggregateAmt,
            U.CurrBal,
            U.VendorTaxID
        FROM View_ContractsByParentVID AS K
        INNER JOIN JDEProject AS P
            ON P.JobNumb = V_MCU
        LEFT JOIN PrequalXML AS U
            ON U.VendorNo = K.PVID
        WHERE P.Division = 'MHF'
        )
GO
