DROP INDEX [NonClusteredIndex-20240122-145223]
    ON [dbo].[PRDOCS];

CREATE INDEX [TransactionStatus_TransferID_DocType] ON [dbo].[PRDOCS] (
    [TransactionStatus],
    [TransferID],
    [DocType]
    ) INCLUDE (
    [ContractNumber],
    [DocNumber],
    [ProjectNumber],
    [ItemAmt]
    );

CREATE INDEX [JDE_CostCode_cost_code_id] ON [dbo].[JMS_CostCode] (
    [cost_code_id],
    [JDE_CostCode],
    [JDE_JobNumber],
    [JDE_MCRP30]
    )

CREATE INDEX [cost_code_id_JDE_JobNumber] ON [dbo].[JMS_CostCode] (
    [cost_code_id],
    [JDE_JobNumber]
    );

CREATE INDEX [AttributeName_Includes] ON [dbo].[k_Attributes] ([AttributeName]) INCLUDE (
    [TransactionID],
    [AttributeValue]
    );

CREATE INDEX [TransactionID_AttributeName_Includes] ON [dbo].[k_Attributes] (
    [TransactionID],
    [AttributeName]
    ) INCLUDE ([AttributeValue]);

CREATE INDEX [project_id_Includes_Includes] ON [dbo].[JMS_CostCode] ([project_id]) INCLUDE (
    [full_code],
    [subjob_code]
    );

CREATE INDEX [cost_code_id_JDE_MCRP30] ON [dbo].[JMS_CostCode] (
    [cost_code_id],
    [JDE_MCRP30]
    )

ALTER TABLE [dbo].[JMS_TierDesc]
ADD CONSTRAINT [pk_Code]
PRIMARY KEY CLUSTERED ([Code])

CREATE INDEX [project_number_Includes] ON [dbo].[JMS_Project] ([project_number])
INCLUDE ([active])

CREATE INDEX [project_Id_Incudes] on [dbo].[JMS_Project] ([project_id])
INCLUDE ([company_id])

CREATE INDEX [BCSTatus_Includes] ON [dbo].[JMS_BudgetControl] ([BCStatus])
INCLUDE ([BCBatchRef],[BCMCRP30])

CREATE INDEX [BCSource_Includes] ON [dbo].[JMS_BudgetControl] ([BCSource])
INCLUDE ([BCUPMJ_T])

CREATE INDEX [project_id_Includes] ON [dbo].[JMS_SubJob] ([project_id])
INCLUDE ([subjob_id],[subjobcode])

CREATE INDEX IX_JMS_BudgetLineItems_Main
ON JMS_BudgetLineItems (
    budget_line_item_id,
    JDE_MCRP30,
    JDE_MCU,
    JDE_SUB,
    JDE_OBJ
);

CREATE INDEX IX_JMS_CostType_Code
ON JMS_CostType (Code)
INCLUDE (line_item_type_id);

CREATE INDEX IX_JMS_CostActivity_DCStatus_MCRP30 
ON JMS_CostActivity (DCStatus, MCRP30);

CREATE INDEX IX_JMS_CostActivity_GBMCU_GBSUB 
ON JMS_CostActivity (GBMCU, GBSUB);

--Optimized Queries

--Original Query #35
UPDATE JMS_CostCode 

SET JDE_JobNumber = quote(Left($JDE_MCRP30,5)) + subjob_code , Jde_CostCode = replace(full_code,'-','') 

where  Len(replace(full_code,'-','')) < 9 and project_id= " + $project_id + "

--Optimized

WITH ProcessedCodes AS (
    SELECT 
        cost_code_id,
        LEN(REPLACE(full_code, '-', '')) as code_length,
        REPLACE(full_code, '-', '') as cleaned_code
    FROM JMS_CostCode
    WHERE project_id = " + $project_id + "
)
UPDATE cc
SET 
    JDE_JobNumber = QUOTE(LEFT($JDE_MCRP30, 5)) + subjob_code,
    Jde_CostCode = pc.cleaned_code
FROM JMS_CostCode cc
INNER JOIN ProcessedCodes pc 
    ON cc.cost_code_id = pc.cost_code_id
WHERE pc.code_length < 9;


