SET STATISTICS IO ON
SET STATISTICS TIME ON
GO

With SurveyResponse as (
        SELECT     
            COALESCE(P.P_ParentVID, R.JDEVendorID) AS JDEVendorID,
            CAST(V.Response AS INT) AS Response,
            V.Class 
        FROM     
            dbo.ProjectSurveyResponse AS R 
        INNER JOIN     
            dbo.ProjectSurveyQuestions AS Q    
            ON Q.QuestionVersion = R.QuestionVersion 
        CROSS APPLY     
            (VALUES
                (Ans01, Q01Class),
                (Ans02, Q02Class),        
                (Ans03, Q03Class),        
                (Ans04, Q04Class),        
                (Ans05, Q05Class),        
                (Ans06, Q06Class),        
                (Ans07, Q07Class),        
                (Ans08, Q08Class),        
                (Ans09, Q09Class),        
                (Ans10, Q10Class)
            ) AS V(Response, Class)
        LEFT JOIN     
            dbo.ParentVendorID AS P   
            ON P.P_VID = R.JDEVendorID 
        WHERE V.Response IS NOT NULL 
            AND V.Response > 0
    ),
    SurveyResponseAggregate AS (
        SELECT JDEVendorID,
            Class,
            AVG(CAST(Response as DECIMAL(4,2))) as AVGResponse,
            COUNT(*) as ClassCount
        FROM SurveyResponse
        GROUP By JDEVendorID, Class
    ),
    ContractsByParentVID AS (
        SELECT 
            C.V_DOCO,
            C.V_MCU,
            C.V_PROJECTNAME,
            C.V_NAME,
            CASE 
                WHEN C.V_CONTRACTAMT < 0 THEN 0
                ELSE C.V_CONTRACTAMT
            END AS V_CONTRACTAMT,
            CASE 
                WHEN C.V_OPENAMT < 0 THEN 0
                ELSE C.V_OPENAMT
            END AS V_OpenAmt,
            C.V_TAXID,
            COALESCE(PVID.P_ParentVID, C.V_VID) AS PVID,
            P.YrJobStart,
            P.StateLocation,
            C.V_PCNTCMPLT,
            COALESCE(E.EE_Name, 'NA') AS EE_Name,
            C.V_SubgRole,
            CONVERT(VARCHAR, DATEADD(DAY, C.V_DateAwarded % 1000 - 1, DATEADD(YEAR, ABS(C.V_DateAwarded / 1000), '1900-01-01')), 111) AS V_DateAwarded,
            C.V_OrigContractAmt
        FROM 
            dbo.ContractsByProject AS C
        INNER JOIN 
            dbo.JDEProject AS P
            ON P.JobNumb = C.V_MCU 
        LEFT JOIN 
            dbo.ParentVendorID AS PVID
            ON PVID.P_VID = C.V_VID 
        LEFT JOIN 
            dbo.EmployeeByProject AS E
            ON E.EE_AN8 = P.PMNumb
        WHERE 
            P.Division != 'ZZZ'

    ),
    SurveyResponse_VID_Class AS (
    SELECT 
        JDEVendorID,
        COALESCE(MAX(CASE WHEN Class = 'Q' THEN AvgResponse END), 0) AS Quality,
        COALESCE(MAX(CASE WHEN Class = 'C' THEN AvgResponse END), 0) AS Contract,
        COALESCE(MAX(CASE WHEN Class = 'H' THEN AvgResponse END), 0) AS Schedule,
        COALESCE(MAX(CASE WHEN Class = 'S' THEN AvgResponse END), 0) AS Safety,
        COALESCE(AVG(ISNULL(AvgResponse,0)), 0) AS Overall,
        SUM(ISNULL(ClassCount,0)) AS CNT
    FROM SurveyResponseAggregate
    GROUP BY JDEVendorID
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
    ProjectCounts AS (
        SELECT 
            PVID,
            SUM(CASE WHEN V_PCNTCMPLT < 100 THEN 1 ELSE 0 END) AS PrjCnt,
            SUM(CASE WHEN V_PCNTCMPLT = 100 THEN 1 ELSE 0 END) AS CmpltCnt
        FROM ContractsByParentVID
        GROUP BY PVID
    ),
    impJDE as ( 
        SELECT 
            CB.PVID AS VendorNo,
            VD.V_Name AS VendorName,
            COALESCE(VD.V_TaxID, '') AS VendorTaxID,
            CB.impCurrBal AS CurrBal,
            COALESCE(SRT.Overall, 0) AS SurveyRank,
            COALESCE(PC.PrjCnt, 0) AS PrjCnt,
            COALESCE(PC.CmpltCnt, 0) AS CmpltCnt
        FROM 
            CurrentBalance AS CB
        INNER JOIN 
            VendorDetails AS VD
            ON VD.PVID = CB.PVID 
        LEFT JOIN 
            SurveyResponse_VID_Class AS SRT
            ON SRT.JDEVendorID = CB.PVID
        LEFT JOIN 
            ProjectCounts AS PC
            ON PC.PVID = CB.PVID
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
            ON Q.VendorNo = JDE.VendorNo 
                OR Q.VendorNo IS NULL AND JDE.VendorNo = 0
        LEFT JOIN Q_financialSafety AS F  WITH (INDEX = RecID_Includes)
            ON F.Recid = Q.QNLINK
        LEFT JOIN Q_TA_DBAQuestion AS TAQ
            ON TAQ.RECID = Q.QNLINK
        wHERE RecordStatus <> 'Void' OR RecordStatus IS NULL
