/*
Table: PRDocs

Remove duplicate indexes
*/
DROP INDEX [NonClusteredIndex-20240122-145223]
    ON [dbo].[PRDOCS];

DROP INDEX [DocType_TransferID] ON [dbo].[PRDOCS]

DROP INDEX [TransactionStatus] ON [dbo].[PRDOCS]

/*
Table: PRDOCS
I really wish thi stable had a candidate for a clustered index/Priimary key
but it doesn't. Many columns have far to many duplicates to make that worth while.
Even with a sorted inserts, performance woul dsuffer.
Optimally, adding an identity column would be the right solution.

ALTER TABLE [dbo].[PRDOCS]
    ADD OD INT IDENTITY(1,1) NOT NULL

It would not hurt anything but woul dhel with the pointer records being created.
It would also help with forwarded records.
https://www.brentozar.com/archive/2016/07/fix-forwarded-records
*/


CREATE INDEX [TransferID_DocType_TransactionStatus_Includes] ON [dbo].[PRDOCS] (
    [TransferID],
    [DocType],
    [TransactionStatus]
    ) INCLUDE (
    [ContractNumber],
    [DocNumber],
    [ProjectNumber],
    [ItemAmt]
    );

CREATE NONCLUSTERED INDEX [DocType_DocTypeCode_ProjectNumber_ItemAmt_Include] ON [dbo].[PRDOCS]
(
	[DocType] ASC,
	[DocTypeCode] ASC,
	[ProjectNumber] ASC,
	[ItemAmt] ASC
)
INCLUDE([DocNumber],[ParentEntityID],[SubLedger]) 

/*
Table: JMS_Vendor
*/
CREATE CLUSTERED INDEX [id] ON [dbo].[JMS_Vendor] ([id])

CREATE INDEX [AttributeName_Includes] ON [dbo].[k_Attributes] ([AttributeName]) INCLUDE (
    [TransactionID],
    [AttributeValue]
    );

CREATE INDEX [TransactionID_AttributeName_Includes] ON [dbo].[k_Attributes] (
    [TransactionID],
    [AttributeName]
    ) INCLUDE ([AttributeValue]);

/*
Table: JMS_CostCode
*/
CREATE INDEX [cost_code_id__JDE_CostCode__JDE_JobNumber__JDE_MCRP30] ON [dbo].[JMS_CostCode] (
    [cost_code_id],
    [JDE_CostCode],
    [JDE_JobNumber],
    [JDE_MCRP30]
    )
CREATE CLUSTERED INDEX [cost_code_id] ON [dbo].[JMS_CostCode] (cost_code_id)


CREATE INDEX [project_id_Includes_Includes] ON [dbo].[JMS_CostCode] ([project_id]) INCLUDE (
    [full_code],
    [subjob_code]
    )

/*
Table: JMS_TierDesc
*/
CREATE CLUSTERED INDEX [Code] ON [dbo].[JMS_TierDesc] ([Code])

/*
Table: JMS_Project
*/

CREATE INDEX [project_number_Includes] ON [dbo].[JMS_Project] ([project_number],[active])

CREATE INDEX [project_Id_Incudes] on [dbo].[JMS_Project] ([project_id])
INCLUDE ([company_id])

/*
Table: JMS_BudgetControl
*/

CREATE INDEX [BCSTatus_Includes] ON [dbo].[JMS_BudgetControl] ([BCStatus])
INCLUDE ([BCBatchRef],[BCMCRP30])

CREATE INDEX [BCSource_Includes] ON [dbo].[JMS_BudgetControl] ([BCSource])
INCLUDE ([BCUPMJ_T])

/*
Table: JMS_SubJob
SubJob_id is unique
Recommend Primary Key on this table.
*/

CREATE CLUSTERED INDEX [subjob_id] ON [dbo].[JMS_SubJob] ([subjob_id])

/*
Add INdex for project_id, with in=cludes subjobcode
*/
CREATE INDEX [project_id_Includes]
ON [dbo].[JMS_SubJob] ([project_id])
INCLUDE (
    [subjobcode]
)

/*
Table: JMS_BudgetLineItems
*/

CREATE INDEX  [budget_line_item_id_JDE_MCRP30_JDE_MCU_JDE_SUB_JDE_OBJ]
ON JMS_BudgetLineItems (
    budget_line_item_id,
    JDE_MCRP30,
    JDE_MCU,
    JDE_SUB,
    JDE_OBJ
);

CREATE INDEX [AccountCodeKey] ON [dbo].[JMS_BudgetLineItems] ([AccountCodeKey])

/*
Table: JMS_CostType
*/

CREATE CLUSTERED INDEX [line_item_type_id] ON [dbo].[JMS_CostType] ([line_item_type_id])

/*
Table: JMS_CostActivity
*/

CREATE INDEX DCStatus_MCRP30 
ON JMS_CostActivity (DCStatus, MCRP30);

CREATE INDEX _GBMCU_GBSUB 
ON JMS_CostActivity (GBMCU, GBSUB);


/*
Optimized Queries

Project:	JDE_9.2_AWS_Procore_Budgets v2 

Original Query #35
*/
UPDATE JMS_CostCode 
SET JDE_JobNumber = quote(Left($JDE_MCRP30, 5)) + subjob_code,
    Jde_CostCode = replace(full_code, '-', '')
where  Len(replace(full_code,'-','')) < 9 and project_id= " + $project_id + "

--Optimized

DECLARE @project_id AS BIGINT = " + project_id + " --DLcllare the variable to prevent trivial plans

WITH ProcessedCodes AS (
    SELECT 
        cost_code_id,
        LEN(REPLACE(full_code, '-', '')) as code_length,
        REPLACE(full_code, '-', '') as cleaned_code
    FROM JMS_CostCode
    WHERE project_id = @project_id
)
UPDATE cc
SET 
    JDE_JobNumber = QUOTE(LEFT($JDE_MCRP30, 5)) + subjob_code,
    Jde_CostCode = pc.cleaned_code
FROM JMS_CostCode cc
INNER JOIN ProcessedCodes pc 
    ON cc.cost_code_id = pc.cost_code_id
WHERE pc.code_length < 9;

-- Original Query

SELECT c.cost_code_id,
    b.line_item_type_id,
    a.JDE_OriginalAmt
FROM JMS_BudgetLineItems AS A
LEFT JOIN JMS_CostType AS b
    ON B.Code = A.JDE_OBJ
LEFT JOIN JMS_CostCode AS C
    ON C.JDE_JobNumber = A.JDE_MCU
        AND C.JDE_CostCode = A.JDE_SUB
WHERE budget_line_item_id IS NULL
    AND c.cost_code_id IS NOT NULL
    AND A.JDE_MCRP30 = c.JDE_MCRP30

-- Optimizaed Query
SELECT 
    c.cost_code_id,
    b.line_item_type_id,
    bli.JDE_OriginalAmt
FROM JMS_BudgetLineItems bli
INNER JOIN JMS_CostCode c  -- Changed to INNER JOIN since we need non-NULL cost_code_id
    ON c.JDE_JobNumber = bli.JDE_MCU
    AND c.JDE_CostCode = bli.JDE_SUB
    AND c.JDE_MCRP30 = bli.JDE_MCRP30
LEFT JOIN JMS_CostType b
    ON b.Code = bli.JDE_OBJ
WHERE bli.budget_line_item_id IS NULL

/*
Key improvements:

1. Changed LEFT JOIN to INNER JOIN for JMS_CostCode since we're filtering 
    for non-NULL cost_code_id anyway
2. Moved the JDE_MCRP30 comparison from WHERE clause to JOIN condition
3. Used more descriptive aliases
4. Removed redundant c.cost_code_id IS NOT NULL condition since it's guaranteed 
    by the INNER JOIN
*/

/*
QUeries like this that pass literal parameters into the query can cause
trivial plans created that only get used once. 
The values in $PROJECT)ID and @JMS_MCRP20 are translted to SQL server 
as literal strings.
This can also cause implicit conversion such as when string values are provided 
for numberic data types.
*/

-- Original Query
UPDATE A1
SET cost_code_id = c.cost_Code_id,
    category_id = b.line_item_type_id,
    project_id = Quote($PROJECT_ID)
FROM JMS_BudgetLineItems AS A1
INNER JOIN JMS_CostType AS b
    ON B.Code = A1.JDE_OBJ
INNER JOIN JMS_CostCode AS C
    ON C.JDE_MCRP30 = A1.JDE_MCU
        AND C.JDE_CostCode = A1.JDE_SUB
WHERE budget_line_item_id IS NULL
    AND c.cost_code_id IS NOT NULL
    AND A1.JDE_MCRP30 = Quote($JDE_MCRP30)

/*
A better approach is to declare variables and set those variables so thazt the
query optimizer build a more accurate execution plan that can be reused.
Proprly typing the variables prevents implecit conversions
*/

DECLARE @PROJECT_ID AS BIGINT
DECLARE @JDE_MCRP30 as VARCHAR(10)

SET @PROJECT_ID = $PROJECT_ID
SET @JDE_MCRP20 = quote($JDE_MCRP30)

UPDATE A1
SET A1.cost_code_id = c.cost_Code_id,
    A1.category_id = b.line_item_type_id,
    A1.project_id = @PROJECT_ID
FROM JMS_BudgetLineItems AS A1
    INNER JOIN JMS_CostType AS b
    ON B.Code = A1.JDE_OBJ
    INNER JOIN JMS_CostCode AS C
    ON C.JDE_MCRP30 = A1.JDE_MCU
        AND C.JDE_CostCode = A1.JDE_SUB
WHERE budget_line_item_id IS NULL
    AND c.cost_code_id IS NOT NULL
    AND A1.JDE_MCRP30 = @JDE_MCRP30

/*
This query Uses 2 subqueries that perform aggregate functions on the table 
JMS_ButgetControl.
It also has complex OR conditions in the where clause that can cause poor index usage and 
possible ambituous results.
*/

UPDATE A
SET BCSTATUS = 'DELETE'
FROM JMS_BudgetControl AS A
INNER JOIN (
    SELECT BCMCRP30,
        MAX(BCUPMJ_T) AS MAXPOSTDATE
    FROM JMS_BudgetControl
    WHERE BCStatus IS NULL
    GROUP BY BCMCRP30
    ) AS DT
    ON DT.BCMCRP30 = A.BCMCRP30
LEFT JOIN (
    SELECT BCMCRP30,
        BCStatus
    FROM JMS_BudgetControl
    WHERE BCStatus = 'OPEN'
    ) AS DT2
    ON DT2.BCMCRP30 = A.BCMCRP30
WHERE A.BCStatus IS NULL
    AND BCUPMJ_T <> MAXPOSTDATE
    OR (
        DT2.BCStatus = 'OPEN'
        AND BCUPMJ_T = MAXPOSTDATE
        )
    OR (BCProject_ID IS NULL)
    OR (
        A.BCSource = 'AALedger'
        AND A.BCStatus IS NULL
        )
    
/*
The refactored query has the following advantages:
1. Combined both subqueries into a single CTE named BudgetControlCTE
2. Used MAX(CASE WHEN...) to get the 'OPEN' status check in the same query
3. Changed the INNER JOIN to a LEFT JOIN to match the original query structure
3. In the WHERE clause:
    a. Added a base condition (A.BCStatus IS NULL OR A.BCStatus = 'OPEN') to 
       filter records upfront.
    b. Used a CASE statement to combine the date-related conditions
    c. Grouped similar conditions together logically
    d. Removed redundant checks for NULL status
*/

WITH BudgetControlCTE AS (
    SELECT 
        BCMCRP30,
        MAX(BCUPMJ_T) AS MAXPOSTDATE,
        MAX(CASE WHEN BCStatus = 'OPEN' THEN 'OPEN' END) AS OpenStatus
    FROM JMS_BudgetControl
    WHERE BCStatus IS NULL OR BCStatus = 'OPEN'
    GROUP BY BCMCRP30
)
UPDATE A
SET BCSTATUS = 'DELETE'
FROM JMS_BudgetControl AS A
LEFT JOIN BudgetControlCTE AS B
    ON B.BCMCRP30 = A.BCMCRP30
WHERE (
    BCProject_ID IS NULL
    OR A.BCSource = 'AALedger'
    OR (
        CASE 
            WHEN A.BCStatus IS NULL AND BCUPMJ_T <> B.MAXPOSTDATE THEN 1
            WHEN B.OpenStatus = 'OPEN' AND BCUPMJ_T = B.MAXPOSTDATE THEN 1
            ELSE 0
        END = 1
    )
) AND (A.BCStatus IS NULL OR A.BCStatus = 'OPEN')

/*
This query uses a sub query with a TOP statement and an Order By statement.
This can have issue with indexing. Also seeking NULL can have a detrimental impact
on index usage.
*/
UPDATE A
SET BCSTATUS = 'OPEN',
    BCBatchRef = Quote($CURR_BATCHREF)
FROM JMS_BudgetControl AS A
INNER JOIN (
    SELECT TOP 5 BCMCRP30
    FROM JMS_BudgetControl
    WHERE BCStatus IS NULL
    ORDER BY BCUPMJ_T
    ) AS DT
    ON DT.BCMCRP30 = A.BCMCRP30
WHERE A.BCStatus IS NULL
    AND BCSource IN ('ADesc', 'JALedger', 'File')

/*
This refactored query has the following advantages.
1. Move the subquery into a CTE to get better plan optimization.
2. Move the WHERE condition BCSource IN ('ADesc', 'JALedger', 'File')
   into the CTE to filter the intende record in the CTE. This prevents hghaving to filter 
   these records during the update process.
   Therefor we are not joining on rows that will just eventually filtered out.

NOTE: The literal values in the WHERE clause shoul dnot be an issue if they do not channge.
*/
WITH Top5BCStatuses AS (
    SELECT TOP 5 BCMCRP30
    FROM JMS_BudgetControl
    WHERE BCStatus IS NULL
        AND BCSource IN ('ADesc', 'JALedger', 'File')
    ORDER BY BCUPMJ_T
)
UPDATE A
SET BCSTATUS = 'OPEN',
    BCBatchRef = Quote($Curr_BatchRef)
FROM JMS_BudgetControl AS A
INNER JOIN Top5BCStatuses DT
    ON DT.BCMCRP30 = A.BCMCRP30

/*
Many queries have literal values passed to WHERE clauses in the form of variables 
passed from Jitterbit.
Such as Quote($JDE_JobNumber).
These values are seen as literal string when executed by SQL server.

This can cause the following issue.:
1. Trivial single use plans. These plans tdo not get reused, they take up space 
   in RAM and wast memory.
2. These can also cause parameter sniffing where a plan isreused but it may not be 
   the most optimized plan for the given query.

To alleviate these conditions there are 2 options.
1. Parameterize the queries.
   Declare variables to handle these values and pass those variables in 
   where conditions.

   EXAMPLE:
   DECLARE @JDE_JobNumber AS VARCHAR(20) = quote($JDE_JobNumber)

   -- now use that variable
   WHERE a.JDE_HobNumber = @JDE_JobNumber
   
   This approach can prevent trivial single use plans from being creates but it does 
   not prevent the problem of parameter sniffing.

2. Append the query hint OPTION (RECOMPILE) to these queries.
   This query hint causes the query engine to recompile the query and not store this 
   execution plan in the plan cache.
   This has the following pros and cons.

   Pros:
   Prevent plan cache polution with single use plans.
   Ensures that th eplan created is the most optimized for the current query.

   Cons:
   Processot time must be used to compile this new plan. Large complex queries should
   not be candidates. Over use of this query hint can cause CPU pressure on the
   SQL Server.

As stated above with the PRDocs table, there are many HEAP tables in these databases.
These tables cause "Forwarded Records" when records grow passed the page boundry.
These tables would benefit greatly from the implementation of a clustered index.
If there isn't a unique or mostly unique column in the table the use of an IDENTITY
column configured as a primary clustered index. This wil prevent forwarded records that 
can seriously impact CPU performance on the server.