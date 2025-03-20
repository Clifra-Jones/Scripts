SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER VIEW [dbo].[VIEW_PendingSurveyVendorByEmployee] as (
Select
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
        Cast(Round(Cast((V.V_Amt - V.V_OpenAmt) as decimal (12,2)) /  (CAST(V.V_Amt as decimal (12,2))+1) *100,0) as Integer)  as PCNT_Paid

-- Select *
From ProjectSurvey as PS
Inner Join View_Survey_Tier1_byParentVID_ByMainJob as V on PS.JDERefno = V.V_PMCU
inner join View_Survey_EEHistory_withRoles_byMainJob as EE  on EE.JPMCU = PS.JDERefno and EE.QuestionType = PS.QuestionType
inner join View_SurveyProjectSummary as VPS on VPS.JobNumb = PS.JDERefno

where PS.Status NOT in ('Completed','Closed') and JDERefno +  RTrim(Cast(V_VID as varchar(8))) not in (
Select Distinct RTrim(ProjectReference) + RTrim(Cast(JDEVendorID as varchar(8))) from projectSurveyResponse)
)
GO
