SET STATISTICS IO ON;
SET STATISTICS TIME ON;
GO

WITH ProjectMCU AS (
    -- Pre-calculate the project MCU to avoid repeated string operations
    SELECT DISTINCT 
        V_MCU,
        LEFT(V_MCU, 5) + '000' AS V_PMCU
    FROM ContractsByProject
),
CombinedVendors AS (
    SELECT 
        P_ParentVID AS V_VID,
        P_VName AS V_Name
    FROM [dbo].[ParentVendorID]
    GROUP BY P_ParentVID, P_VName
    
    UNION
    
    SELECT 
        V_VID,
        V_Name
    FROM [dbo].[ContractsByProject]
    GROUP BY V_VID, V_NAME
),
CombinedVendorsWithRowNumbers AS (
    SELECT 
        V_VID,
        V_Name,
        ROW_NUMBER() OVER (
            PARTITION BY V_VID 
            ORDER BY V_Name DESC  -- Or another meaningful ordering column
        ) AS rn
    FROM CombinedVendors
),
LatestVendorNames AS (
    SELECT 
        V_VID,
        V_Name
    FROM 
        CombinedVendorsWithRowNumbers
    WHERE rn = 1
),
ProjectContracts AS (
    SELECT 
        LEFT(V_MCU, 5) + '000' AS V_PMCU,
        COALESCE(P_ParentVID, V_VID) AS V_VID,
        MIN(V_DOCO) AS V_DOCO,
        SUM(V_ContractAmt) AS V_Amt,
        SUM(V_OpenAmt) AS V_OpenAmt,
        Division
    FROM ContractsByProject
    LEFT JOIN ParentVendorID 
        ON P_VID = V_VID
    INNER JOIN JDEProject AS JDE  
        ON LEFT(V_MCU, 5) + '000' = JobNumb
    GROUP BY 
        LEFT(V_MCU, 5),
        COALESCE(P_ParentVID, V_VID),
        Division
    HAVING SUM(V_ContractAmt) >= CASE 
        WHEN Division = 'SWE' THEN 250000 
        ELSE 450000 
        END
),
Survey_Tier1_byParentVID_ByMainJob AS (
    SELECT 
        PC.V_Amt,
        pc.V_DOCO,
        PC.V_OpenAmt,
        PC.V_VID,
        PC.V_PMCU,
        LVN.V_Name
    FROM ProjectContracts AS PC
    INNER JOIN LatestVendorNames AS LVN
        ON LVN.V_VID = PC.V_VID
),
Survey_EEHistory_withRoles_byMainJob AS (
    SELECT DISTINCT EE_AN8,
            Left(JH_HistoryMCU, 5) + '000' AS JPMCU,
            E.EE_Email,
            EE_JobClass,
            EE_ADName,
            EE_Name,
            R.RoleCategory,
            Q.QuestionType
        FROM EmployeeByProject AS E
        INNER JOIN EmployeeJobHistory AS J
            ON E.EE_AN8 = J.JH_AN8
        INNER JOIN ProjectSurveyRole AS R
            ON R.RoleRefNo = E.EE_JobClass
        INNER JOIN ProjectSurveyQuestions AS Q
            ON Q.QuestionVersion = R.RoleCategory
        WHERE JH_JTHR > 8000
),
ProjectGroups AS (
    SELECT 
        ProjectGroup,
        SUM(V_ContractAmt) AS Kamt,
        SUM(V_OpenAmt) AS OpenAmt
    FROM dbo.ContractsByProject
    GROUP BY ProjectGroup
),
JDEProjectGroups AS (
    SELECT 
        ProjectGroup,
        SUM(JobIncome) AS JobIncome
    FROM dbo.JDEProject
    GROUP BY ProjectGroup
),
PaymentDates AS (
    SELECT 
        ProjectGroup,
        MIN(B_FirstPmtDate) AS FirstPmtDate,
        MAX(B_LatestPmtDate) AS LatestPmtDate
    FROM dbo.ContractsByPayment
    GROUP BY ProjectGroup
),
SurveyProjectSummary AS (
    SELECT 
        J.JobNumb,
        CAST(ROUND(
            CAST((G.Kamt - G.OpenAmt) AS DECIMAL(12, 2)) / NULLIF(CAST(G.Kamt AS DECIMAL(12, 2)), 0) * 100
        , 0) AS BIGINT) AS PCNT_Paid,
        COALESCE(B.FirstPmtDate, 0) AS FirstPmtDate,
        COALESCE(B.LatestPmtDate, 0) AS LatestPmtDate
    FROM ProjectGroups G
    INNER JOIN JDEProjectGroups P ON P.ProjectGroup = G.ProjectGroup
    INNER JOIN JDEProject J ON J.JobNumb = G.ProjectGroup
    LEFT JOIN PaymentDates B ON B.ProjectGroup = G.ProjectGroup
    WHERE (
        P.JobIncome > 10000000
        AND J.DateSubguardPolicyStart > 108270
        AND J.Subguard = 'YES'
        AND J.ProjectType != 'MLH'
    ) OR (B.FirstPmtDate > 112183)
)
SELECT
    PS.JDERefNo,
    PS.Description,
    'NA' as ParentLink,
    EE.EE_Email,
    EE.EE_JobClass,
    EE.EE_ADName,
    EE.EE_Name,
    V.V_VID,
    V.V_Name,
    V.V_DOCO,
    EE.RoleCategory,
    EE.QuestionType,
    PS.SurveyHistory,
    VPS.PCNT_Paid as Job_PCNT,
    CAST(ROUND(CAST((V.V_Amt - V.V_OpenAmt) as DECIMAL(12,2)) / (CAST(V.V_Amt as DECIMAL(12,2))+1) * 100, 0) as INTEGER) as PCNT_Paid
FROM dbo.ProjectSurvey PS
INNER JOIN Survey_Tier1_byParentVID_ByMainJob V 
    ON PS.JDERefno = V.V_PMCU
INNER JOIN Survey_EEHistory_withRoles_byMainJob EE  
    ON EE.JPMCU = PS.JDERefno 
    AND EE.QuestionType = PS.QuestionType
INNER JOIN SurveyProjectSummary VPS 
    ON VPS.JobNumb = PS.JDERefno
LEFT JOIN projectSurveyResponse PSR
    ON PSR.ProjectReference = PS.JDERefno
    AND PSR.JDEVendorID = V.V_VID 
WHERE  PSR.ProjectReference IS NULL
    AND (PS.Status != 'Completed' AND PS.[Status] != 'Closed') 
