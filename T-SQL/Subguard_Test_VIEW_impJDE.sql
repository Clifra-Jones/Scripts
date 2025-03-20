SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

ALTER  VIEW [dbo].[VIEW_impJDE] as
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
            ON R.JDEVendorID = P.P_VID 
            WHERE     ISNULL(V.Response, 0) > 0 
    ),
    SurveyResponseAggregate AS (
        SELECT JDEVendorID,
            Class,
            AVG(CAST(Response as DECIMAL(4,2))) as AVGResponse,
            COUNT(*) as ClassCount
        FROM SurveyResponse
        GROUP By JDEVendorID, Class
    ),
    OverallAggregate AS (
        SELECT JDEVendorId,
            ROUND(AVG(CAST(Response AS DECIMAL(4,2))),1) as Overall
        FROM SurveyResponse
        GROUP BY JDEVendorID
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
            ON C.V_MCU = P.JobNumb
        LEFT JOIN 
            dbo.ParentVendorID AS PVID
            ON PVID.P_VID = C.V_VID
        LEFT JOIN 
            dbo.EmployeeByProject AS E
            ON E.EE_AN8 = P.PMNumb
        WHERE 
            P.Division != ('ZZZ')

    ),
    SurveyResponse_VID_Class AS (
    SELECT 
        SRA.JDEVendorID,
        COALESCE(MAX(CASE WHEN Class = 'Q' THEN AvgResponse END), 0) AS Quality,
        COALESCE(MAX(CASE WHEN Class = 'C' THEN AvgResponse END), 0) AS Contract,
        COALESCE(MAX(CASE WHEN Class = 'H' THEN AvgResponse END), 0) AS Schedule,
        COALESCE(MAX(CASE WHEN Class = 'S' THEN AvgResponse END), 0) AS Safety,
        MAX(Overall) AS Overall,
        SUM(ISNULL(ClassCount,0)) AS CNT
    FROM SurveyResponseAggregate SRA
	INNER JOIN OverallAggregate OA
	ON SRA.JDEVendorID = OA.JDEVendorID
    GROUP BY SRA.JDEVendorID
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
    )
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
            ON CB.PVID = VD.PVID
        LEFT JOIN 
            SurveyResponse_VID_Class AS SRT
            ON SRT.JDEVendorID = CB.PVID
        LEFT JOIN 
            ProjectCounts AS PC
            ON PC.PVID = CB.PVID

GO
