/*
Database: Subguard_Test
*/
/*
Table: ProjectSurveyQuestions
*/
ALTER TABLE [dbo].[ProjectSurveyQuestions] ADD CONSTRAINT [ProjectSurveyQuestionsRecId] PRIMARY KEY CLUSTERED ([RecId] ASC)

CREATE NONCLUSTERED INDEX [QuestionVersion] ON [dbo].[ProjectSurveyQuestions] ([QuestionVersion] ASC)

/*
Table: ParentVendorID
*/
ALTER TABLE [dbo].[ParentVendorID] ADD PRIMARY KEY CLUSTERED ([P_VID] ASC)

CREATE NONCLUSTERED INDEX [P_ParentVID_Include] ON [dbo].[ParentVendorID] ([P_ParentVID] ASC) INCLUDE ([P_VName])

/*
Table: ContractsByProject
*/
CREATE CLUSTERED INDEX [V_DOCO_V_MCU_V_VID] ON [dbo].[ContractsByProject] (
        [V_DOCO] ASC,
        [V_MCU] ASC,
        [V_VID] ASC
    )

CREATE NONCLUSTERED INDEX [V_MCU_INCLUDES] ON [dbo].[ContractsByProject] ([V_MCU] ASC) INCLUDE (
        [V_VID],
        [V_PCNTCMPLT],
        [V_TAXID],
        [V_OPENAMT]
    )

CREATE NONCLUSTERED INDEX [V_VID_Includes] ON [dbo].[ContractsByProject] ([V_VID] ASC) INCLUDE (
        [V_DOCO],
        [V_MCU],
        [V_PROJECTNAME],
        [V_NAME],
        [V_CONTRACTAMT],
        [V_OPENAMT],
        [V_TAXID],
        [V_PCNTCMPLT],
        [V_SubgRole],
        [V_DateAwarded],
        [V_OrigContractAmt]
    )

/*
Table: JDEProject
*/
CREATE CLUSTERED INDEX [JobNumb] ON [dbo].[JDEProject] ([JobNumb] ASC)

CREATE NONCLUSTERED INDEX [PMNumb_Division] ON [dbo].[JDEProject] (
        [PMNumb] ASC,
        [Division] ASC
    )

/*
Table: WatchList
*/
ALTER TABLE [dbo].[WatchList] ADD CONSTRAINT [PK_WL_Id] PRIMARY KEY CLUSTERED ([WL_Id] ASC)

CREATE NONCLUSTERED INDEX [WL_PVID_Include] ON [dbo].[WatchList] ([WL_PVID] ASC) INCLUDE (
        [WL_Flag],
        [WL_Who]
    )

/*
Table: Q_WorkHistory
*/
CREATE CLUSTERED INDEX [RecID] ON [dbo].[Q_WorkHistory] ([RecID] ASC)

CREATE CLUSTERED INDEX RecID on [dbo].[Q_FinancialSafety] (RecID)

CREATE NONCLUSTERED INDEX RecID_Includes on [dbo].[Q_FinancialSafety] (RecID)
INCLUDE (
    OshaFatalyr1,
    oshaTRIRyr1, 
    oshaDARTyr1, 
    OshaFatalyr2,
    oshaTRIRyr2, 
    oshaDARTyr2, 
    OshaFatalyr3,
    oshaTRIRyr3, 
    oshaDARTyr3
)

CREATE CLUSTERED INDEX RecId ON [dbo].[Q_TA_DBAQuestion] (RecID)

CREATE NONCLUSTERED INDEX REC_ID_Includes ON [dbo].[Q_TA_DBAQuestion] (RecID)
INCLUDE (DBAQuestion)

CREATE CLUSTERED INDEX ID ON [dbo].[T2Prequal] (ID)

