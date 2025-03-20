UPDATE PRDOCS
SET PRDOCS.AwardDate = AT.AwardDate,
    PRDOCS.PrimaryBudgetCode = AT.PrimaryBudgetCode,
    PRDOCS.RetainageWorkInPlace = AT.RetainageWorkInPlace,
    PRDOCS.LastModEmail = AT.EmailAddress
FROM PRDOCS
INNER JOIN (
    SELECT DISTINCT A1.TransactionID,
        AwardDate,
        PrimaryBudgetCode,
        RetainageWorkInPlace,
        GreenFootPrint,
        JDEPmtTerms,
        SubguardClass,
        EmailAddress
    FROM k_Attributes AS A1(NOLOCK)
    LEFT JOIN (
        SELECT TransactionID,
            AttributeValue AS AwardDate
        FROM k_Attributes(NOLOCK)
        WHERE AttributeName = 'AwardDate'
        ) AS A2
        ON A1.TransactionID = A2.TransactionID
    LEFT JOIN (
        SELECT TransactionID,
            AttributeValue AS PrimaryBudgetCode
        FROM k_Attributes(NOLOCK)
        WHERE AttributeName = 'PrimaryBudgetCode'
        ) AS A3
        ON A1.TransactionID = A3.TransactionID
    LEFT JOIN (
        SELECT TransactionID,
            AttributeValue AS RetainageWorkInPlace
        FROM k_Attributes(NOLOCK)
        WHERE AttributeName = 'RetainageWorkInPlace'
        ) AS A4
        ON A1.TransactionID = A4.TransactionID
    LEFT JOIN (
        SELECT TransactionID,
            AttributeValue AS GreenFootPrint
        FROM k_Attributes(NOLOCK)
        WHERE AttributeName = 'GreenFootPrint'
        ) AS A6
        ON A1.TransactionID = A6.TransactionID
    LEFT JOIN (
        SELECT TransactionID,
            AttributeValue AS JDEPmtTerms
        FROM k_Attributes(NOLOCK)
        WHERE AttributeName = 'JDEPmtTerms'
        ) AS A7
        ON A1.TransactionID = A7.TransactionID
    LEFT JOIN (
        SELECT TransactionID,
            AttributeValue AS SubguardClass
        FROM k_Attributes(NOLOCK)
        WHERE AttributeName = 'SubguardClass'
        ) AS A8
        ON A1.TransactionID = A8.TransactionID
    LEFT JOIN (
        SELECT TransactionID,
            AttributeValue AS EmailAddress
        FROM k_Attributes(NOLOCK)
        WHERE AttributeName = 'user_id'
        ) AS A9
        ON A1.TransactionID = A9.TransactionID
    ) AS AT
    ON AT.TransactionID = PRDOCS.TransactionID
WHERE PRDOCS.TransferID = '" + $trg_transferID +"'


WITH AttributeData AS (
    SELECT 
        TransactionID,
        MAX(CASE WHEN AttributeName = 'AwardDate' THEN AttributeValue END) AS AwardDate,
        MAX(CASE WHEN AttributeName = 'PrimaryBudgetCode' THEN AttributeValue END) AS PrimaryBudgetCode,
        MAX(CASE WHEN AttributeName = 'RetainageWorkInPlace' THEN AttributeValue END) AS RetainageWorkInPlace,
        MAX(CASE WHEN AttributeName = 'GreenFootPrint' THEN AttributeValue END) AS GreenFootPrint,
        MAX(CASE WHEN AttributeName = 'JDEPmtTerms' THEN AttributeValue END) AS JDEPmtTerms,
        MAX(CASE WHEN AttributeName = 'SubguardClass' THEN AttributeValue END) AS SubguardClass,
        MAX(CASE WHEN AttributeName = 'user_id' THEN AttributeValue END) AS EmailAddress
    FROM k_Attributes (NOLOCK)
    GROUP BY TransactionID
)
UPDATE PRDOCS
SET 
    PRDOCS.AwardDate = AD.AwardDate,
    PRDOCS.PrimaryBudgetCode = AD.PrimaryBudgetCode,
    PRDOCS.RetainageWorkInPlace = AD.RetainageWorkInPlace,
    PRDOCS.LastModEmail = AD.EmailAddress
FROM PRDOCS
INNER JOIN AttributeData AS AD
    ON PRDOCS.TransactionID = AD.TransactionID
WHERE PRDOCS.TransferID = '" + $trg_transferID + "'


SELECT COUNT(8), TransactionId
FROM PRDOCS
GROUP BY TransactionID
Having COUNT(*) > 1

CREATE CLUSTERED INDEX TransactionId
    ON k_Attributes(TransactionID)

CREATE NONCLUSTERED INDEX IX_k_Attributes_AttributeName 
    ON k_Attributes(AttributeName)
    INCLUDE (AttributeValue);

CREATE NONCLUSTERED INDEX IX_PRDOCS_TransferID 
    ON PRDOCS(TransferID);

CREATE NONCLUSTERED INDEX IX_PRDOCS_TransactionID 
ON PRDOCS(TransactionID);
