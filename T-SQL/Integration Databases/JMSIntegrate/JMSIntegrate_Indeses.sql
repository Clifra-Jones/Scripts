CREATE INDEX [DocType_DocTypeCode_ProjectNumber_ItemAmt_Include] ON [JMSIntegrate_Test].[dbo].[PRDOCS] (
    [DocType],
    [DocTypeCode],
    [ProjectNumber],
    [ItemAmt]
    ) INCLUDE (
    [DocNumber],
    [ParentEntityID],
    [SubLedger]
    );

--DROP INDEX [DocType_DocTypeCode_ProjectNumber_ItemAmt_Include] ON [JMSIntegrate_Test].[dbo].[PRDOCS];

CREATE INDEX [DocType_TransferID] ON [JMSIntegrate_Test].[dbo].[PRDOCS] (
    [DocType],
    [TransferID]
);

--DROP INDEX [DocType_TransferID] ON [JMSIntegrate_Test].[dbo].[PRDOCS];

CREATE NONCLUSTERED INDEX [TransactionStatus] ON [dbo].[PRDOCS]
(
	[TransactionStatus] ASC
)

--DROP INDEX [TransactionStatus] ON [dbo].[PRDOCS]

CREATE NONCLUSTERED INDEX [TransferID] ON [dbo].[PRDOCS]
(
	[TransferID] ASC
)

--DROP INDEX [TransferID] ON [dbo].[PRDOCS]
