SET STATISTICS IO ON;
SET STATISTICS TIME ON;
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
        ON CB.PVID = VD.PVID
    LEFT JOIN 
        SurveyResponse_VID_Class AS SRT
        ON SRT.JDEVendorID = CB.PVID
    LEFT JOIN 
        ProjectCounts AS PC
        ON PC.PVID = CB.PVID
),
WatchListCommentators as (
    SELECT WL_PVID
    , Cast(STUFF((
                SELECT ',' + WL_Who
                FROM (
                    SELECT DISTINCT WL_PVID
                        , WL_Who
                    FROM watchlist
                    ) AS SubWL
                WHERE SubWL.WL_PVID = MainWL.WL_PVID
                FOR XML PATH('')
                ), 1, 1, '') AS VARCHAR(500)) AS People
FROM Watchlist AS MainWL
GROUP BY WL_PVID
),
WatchlistDistinct AS (
    SELECT DISTINCT W.WL_PVID
        , W.WL_Flag
        , C.People
    FROM dbo.Watchlist AS W
    INNER Join WatchListCommentators AS C
        ON W.WL_PVID = C.WL_PVID 
    WHERE WL_Flag = 'Y'
)
Select 
    PQ.Vendor
    , PQ.VendorNo
    , PQ.SingleAmt
    , PQ.AggregateAmt
    , PQ.Division
    , PQ.QuestionnaireDate
    , PQ.STATUS
    , PQ.TradeDescription
    , PQ.RequestFirstDate
    , PQ.RequestSecondDate
    , PQ.RequestThirdDate
    , PQ.Chk_ProjHistory
    , PQ.Chk_Financials
    , PQ.Chk_BackLog
    , PQ.Chk_SalesHistory
    , PQ.Chk_BondHistory
    , PQ.Chk_ProjectList
    , PQ.Chk_KeyOfficer
    , PQ.Chk_OSHA_Log
    , PQ.Chk_Questionnaire
    , PQ.ZeroHarmQ
    , PQ.VendorEmail
    , PQ.VendorAddr
    , PQ.VendorCity
    , PQ.VendorState
    , PQ.VendorZip
    , Convert(VARCHAR(10), PQ.ExpirationDate, 101) AS ExpirationDate
    , CASE IsNumeric(JDE.CurrBal)
        WHEN 1
            THEN JDE.Currbal
        ELSE 0
        END AS CurrBal
    , PQ.MinorityStatus
    , CASE 
        WHEN PQ.PublicFolder != ''
            THEN PQ.PublicFolder + '\' + PQ.PublicSubFolder
        ELSE ''
        END AS Folder
    , JDE.VendorTaxID
    , SRk.Overall AS vendorrank
    , SRk.Quality AS QR
    , SRk.Safety AS SR
    , SRk.Schedule AS HR
    , SRk.Contract AS CR
    , PQ.QnLink
    , CASE 
        WHEN Q.ProjectName4 <> ''
            THEN 4
        WHEN Q.ProjectName3 <> ''
            THEN 3
        WHEN Q.ProjectName2 <> ''
            THEN 2
        WHEN Q.ProjectName1 <> ''
            THEN 1
        ELSE 0
        END AS QProjects
    , Coalesce(JDE.PrjCnt, 0) AS PrjCnt
    , Coalesce(JDE.CmpltCnt, 0) AS CmpltCnt
    , Coalesce(WL.WL_Flag, 'N') AS WatchList
    , Coalesce(WL.People, '') AS WatchListPeople
    , PQ.ID AS RecID
    , CASE IsNumeric(PQ.CurrBalVID)
        WHEN 1
            THEN PQ.CurrBalVID
        ELSE PQ.VendorNO
        END AS PLookupVID
    , Coalesce(PQ.TypicalJobSize, 0) AS TypicalJobSize
FROM dbo.PreQual AS PQ
LEFT JOIN impJDE AS JDE
    ON (PQ.CurrBalVID = JDE.VendorNo OR (PQ.CurrBalVID IS NULL AND PQ.VendorNo = JDE.VendorNo))
LEFT JOIN SurveyResponse_VID_Class AS SRk
    ON PQ.VendorNo = SRk.JDEVendorID
LEFT JOIN dbo.Q_WorkHistory AS Q
    ON Q.Recid = QNLink
-- added Apr 30,2012
LEFT JOIN WatchlistDistinct AS WL
    ON WL.WL_PVID = PQ.VendorNo
-- added Nov 10, 2011
WHERE PQ.STATUS <> 'INACTIVE'
ORDER By PQ.VendorNo

OPTION (RECOMPILE)
