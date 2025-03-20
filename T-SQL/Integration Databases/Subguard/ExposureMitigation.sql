SET STATISTICS IO ON
SET STATISTICS TIME ON
GO

With ContractsByParentVID AS (
        SELECT 
            C.V_NAME,
            CASE 
                WHEN C.V_OPENAMT < 0 THEN 0
                ELSE C.V_OPENAMT
            END AS V_OpenAmt,
            C.V_TAXID,
            COALESCE(PVID.P_ParentVID, C.V_VID) AS PVID,
            C.V_PCNTCMPLT
        FROM 
            dbo.ContractsByProject AS C
        INNER JOIN 
            dbo.JDEProject AS P
            ON P.JobNumb = C.V_MCU 
        LEFT JOIN 
            dbo.ParentVendorID AS PVID
            ON PVID.P_VID = C.V_VID 
        WHERE 
            P.Division != 'ZZZ'

    ),
    VendorDetails AS (
        SELECT 
            PVID, 
            MAX(V_Name) AS V_Name, 
            MAX(V_TaxID) AS V_TaxID
        FROM ContractsByParentVID
        GROUP BY PVID
    ),
    CurrentBalance AS (
        SELECT 
            PVID, 
            SUM(CASE WHEN V_PCNTCMPLT = 100 THEN 0 ELSE ISNULL(V_OpenAmt,0) END) AS impCurrBal
        FROM ContractsByParentVID
        GROUP BY PVID
    ),
    impJDE as ( 
        SELECT 
            CB.PVID AS VendorNo,
            CB.impCurrBal AS CurrBal
        FROM 
            CurrentBalance AS CB
        INNER JOIN 
            VendorDetails AS VD
            ON VD.PVID = CB.PVID 
    )

    SELECT SubmittedTaxid,
            vendor,
            IsNull(Replace(Replace(TAQ.DBAQuestion, CHAR(13), ';'), CHAR(10), ''), '') AS DBA,
            CASE 
                WHEN Len(P.ExpirationDate) > 0
                    THEN convert(VARCHAR, P.ExpirationDate, 101)
                ELSE ''
                END AS ExpirationDate,
            IsNull(F.BondSPL, '') AS Subc_BondLimit,
            P.SingleAmt AS BBC_SingleLimit,
            P.AggregateAmt AS BBC_AggregateLimit,
            CASE IsNumeric(JDE.CurrBal)
                WHEN 1
                    THEN JDE.Currbal
                ELSE 0
                END AS BBC_OpenBal,
            STATUS,
            IsNull(P.EMR_Year_1, '') AS Year1,
            IsNull(P.EMR_Rate_1, '') AS EMR1,
            IsNull(F.OshaFatalyr1, '') AS Fatal1,
            IsNull(F.oshaTRIRyr1, '') AS TRIR1,
            IsNull(F.oshaDARTyr1, '') AS DART1,
            IsNull(P.EMR_Year_2, '') AS Year2,
            IsNull(P.EMR_Rate_2, '') AS EMR2,
            IsNull(F.OshaFatalyr2, '') AS Fatal2,
            IsNull(F.oshaTRIRyr2, '') AS TRIR2,
            IsNull(F.oshaDARTyr2, '') AS DART2,
            IsNull(P.EMR_Year_3, '') AS Year3,
            IsNull(P.EMR_Rate_3, '') AS EMR3,
            IsNull(F.OshaFatalyr3, '') AS Fatal3,
            IsNull(F.oshaTRIRyr3, '') AS TRIR3,
            IsNull(F.oshaDARTyr3, '') AS DART3,
            P.vendorAddr,
            P.VendorCity,
            P.VendorState,
            P.VendorZip,
            P.DateLastMod,
            'P' AS Srce
        FROM dbo.PreQual AS P
        LEFT JOIN impJDE AS JDE
           ON (P.CurrBalVID = JDE.VendorNo OR (P.CurrBalVID IS NULL AND P.VendorNo = JDE.VendorNo))
        LEFT JOIN dbo.Q_financialSafety AS F WITH (INDEX = RecID_Includes)
            ON F.Recid = P.QNLink 
        LEFT JOIN dbo.Q_TA_DBAQuestion AS TAQ
            ON TAQ.RECID = P.QnLink 
        WHERE P.STATUS <> 'INACTIVE'

        UNION
        
        SELECT submittedTaxID,
            vendor,
            IsNull(Replace(Replace(DBAQuestion, CHAR(13), ';'), CHAR(10), ''), '') AS DBA,
            'NA' AS ExpirationDate,
            IsNull(BondSPL, '') AS Subc_BondLimit,
            0 AS BBC_SingleLimit,
            0 AS BBC_AggregateLimit,
            Coalesce(JDE.CurrBal, 0) AS BBC_OpenBal,
            'NoPrequal' AS STATUS,
            IsNull(F.EMRYr1, '') AS Year1,
            IsNull(F.EMRNumb1, '') AS EMR1,
            IsNull(F.OshaFatalyr1, '') AS Fatal1,
            IsNull(F.oshaTRIRyr1, '') AS TRIR1,
            IsNull(F.oshaDARTyr1, '') AS DART1,
            IsNull(F.EMRYr2, '') AS Year2,
            IsNull(F.EMRNumb2, '') AS EMR2,
            IsNull(F.OshaFatalyr2, '') AS Fatal2,
            IsNull(F.oshaTRIRyr2, '') AS TRIR3,
            IsNull(F.oshaDARTyr2, '') AS DART2,
            IsNull(F.EMRYr3, '') AS Year3,
            IsNull(F.EMRNumb3, '') AS EMR3,
            IsNull(F.OshaFatalyr3, '') AS Fatal3,
            IsNull(F.oshaTRIRyr3, '') AS TRIR3,
            IsNull(F.oshaDARTyr3, '') AS DART3,
            VendorAddr,
            VendorCity,
            VendorState,
            VendorZip,
            QuestionnaireDate,
            'T' AS Srce
        FROM DBO.T2Prequal AS Q
        LEFT JOIN impJDE AS JDE
            ON JDE.VendorNo = Q.VendorNo
        LEFT JOIN Q_financialSafety AS F  WITH (INDEX = RecID_Includes)
            ON F.Recid = Q.QNLINK
        LEFT JOIN Q_TA_DBAQuestion AS TAQ
            ON TAQ.RECID = Q.QNLINK
        wHERE RecordStatus <> 'Void' OR RecordStatus IS NULL
