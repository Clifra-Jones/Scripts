SET STATISTICS IO ON;
SET STATISTICS Time ON;
GO

WITH ContractsByParentVID as (
    SELECT V_DOCO,
        V_MCU,
        V_PROJECTNAME,
        V_NAME,
        CASE 
            WHEN V_CONTRACTAMT < 0
                THEN 0
            ELSE V_CONTRACTAMT
            END V_CONTRACTAMT,
        CASE 
            WHEN V_OPENAMT < 0
                THEN 0
            ELSE V_OpenAmt
            END V_OpenAmt,
        V_TAXID,
        Coalesce(P_ParentVID, V_VID) AS PVID,
        YrJobStart,
        StateLocation,
        V_PCNTCMPLT,
        coalesce(EE_Name, 'NA') AS EE_Name,
        V_SubgRole,
        Convert(VARCHAR, DateAdd(DAY, V_DateAwarded % 1000 - 1, DateAdd(YEAR, ABS(V_DateAwarded / 1000), Cast('1900-01-01' AS DATETIME))), 111) AS V_DateAwarded,
        V_OrigContractAmt
    FROM dbo.ContractsByProject
    INNER JOIN dbo.JDEProject AS P
        ON JobNumb = V_MCU
    LEFT JOIN dbo.ParentVendorID
        ON P_VID = V_VID
    LEFT JOIN dbo.EmployeeByProject
        ON EE_AN8 = P.PMNumb
    WHERE P.Division != 'ZZZ'
),
VendorDetails AS (
    SELECT 
        PVID, 
        MAX(V_Name) AS V_Name, 
        MAX(V_TaxID) AS V_TaxID
    FROM ContractsByParentVID
    GROUP BY PVID
),CurrentBalance AS (
        SELECT 
            PVID, 
            SUM(CASE WHEN V_PCNTCMPLT = 100 THEN 0 ELSE ISNULL(V_OpenAmt,0) END) AS impCurrBal
        FROM ContractsByParentVID
        GROUP BY PVID
),
impJDE AS (
    SELECT
        CB.PVID AS VendorNo,
        COALESCE(VD.V_TAXID, '') as VendorTaxId,
        CB.impCurrBAl as CurrBal
    FROM
        CurrentBalance AS CB
    INNER JOIN
        VendorDetails AS VD
        ON VD.PVID = CB.PVID
),
cte_Prequal AS (
    Select 
        JDE.VendorNo,
        PQ.SingleAmt,
        PQ.AggregateAmt,
        JDE.CurrBal,
        JDE.VendorTaxId
    From 
        dbo.PreQual as PQ
    LEFT Join impJDE AS JDE
    On (PQ.CurrBalVID = JDE.VendorNo OR (PQ.CurrBalVID IS NULL AND PQ.VendorNo = JDE.VendorNo))
)

SELECT TOP 10 k.*,
    U.SingleAmt,
    U.aggregateAmt,
    U.CurrBal,
    U.VendorTaxID
FROM ContractsByParentVID AS K
INNER JOIN JDEProject AS P
    ON P.JobNumb = V_MCU
LEFT JOIN cte_Prequal AS U
    ON U.VendorNo = K.PVID
WHERE P.Division = 'MHF'
