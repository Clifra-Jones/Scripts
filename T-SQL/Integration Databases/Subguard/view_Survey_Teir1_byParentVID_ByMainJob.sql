SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER View [dbo].[View_Survey_Tier1_byParentVID_ByMainJob]

AS

WITH ProjectMCU AS (
    -- Pre-calculate the project MCU to avoid repeated string operations
    SELECT DISTINCT 
        V_MCU,
        LEFT(V_MCU, 5) + '000' AS V_PMCU
    FROM ContractsByProject
),
VendorName_with_Rownum as (
    SELECT A.*,
            ROW_NUMBER() OVER (
                ORDER BY V_VID ASC
                ) AS row_Numb
    FROM (
            SELECT P_ParentVID AS V_VID,
                P_VName AS V_Name
            FROM ParentVendorID
            
            UNION
            
            SELECT DISTINCT V_VID,
                V_NAme
            FROM ContractsByProject
        ) AS A
),
LatestVendorNames AS (
    -- Get the most recent vendor name using ROW_NUMBER instead of subquery
    SELECT 
        V_VID,
        V_Name
    FROM (
        SELECT 
            V_VID,
            V_Name,
            ROW_NUMBER() OVER (PARTITION BY V_VID ORDER BY row_Numb DESC) AS rn
        FROM View_VendorName_With_Rownum
    ) ranked
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
)
SELECT 
    PC.*,
    LVN.V_Name
FROM ProjectContracts AS PC
INNER JOIN LatestVendorNames AS LVN
    ON LVN.V_VID = PC.V_VID;