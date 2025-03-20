SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



ALTER   View [dbo].[View_ExposureMitigation] as (

Select 
coalesce(GuidID,'') as GuidID,
coalesce(PrequalID,'') as PrequalID,
coalesce(CreatedDate,'') as CreatedDate,
coalesce(CreatedBy,'') as CreatedBy,
coalesce(ProjectName,'') as ProjectName,
coalesce(ProjectNumber,'') as ProjectNumber,
coalesce(SubcName,'') as SubcName,
coalesce(SubcAddress,'') as SubcAddress,
coalesce(SubcCity,'') as SubcCity,
coalesce(SubcState,'') as SubcState,
coalesce(SubcZip,'') as SubcZip,
coalesce(TradeDesc,'') as TradeDesc,
coalesce(ActionNeeded,'') as ActionNeeded,
coalesce(ActionNeededDesc,'') as ActionNeededDesc,
coalesce(SuretyType,'') as SuretyType,
coalesce(SuretyDesc,'') as SuretyDesc,
coalesce(inpPrice,'0') as inpPrice,
coalesce(inpBBCPrice,'0') as inpBBCPrice,
coalesce(inpPreqStatus,'') as inpPreqStatus,
coalesce(inpBondableBid,'0') as inpBondableBid,
coalesce(inpSPL,'0') as inpSPL,
coalesce(inpAggLimit,'0') as inpAggLimit,
coalesce(inpProposedCO,'0') as inpProposedCO,
coalesce(inpCurrOpenAmt,'0') as inpCurrOpenAmt,
coalesce(inpRevisedAmt,'0') as inpRevisedAmt,
coalesce(inpSubcStartDate,'') as inpSubcStartDate,
coalesce(REPLACE(REPLACE(txtPriorExp, CHAR(13), ''), CHAR(10), ''),'') as txtPriorExp,
coalesce(REPLACE(REPLACE(txtOtherSecurity, CHAR(13), ''), CHAR(10), ''),'') as txtOtherSecurity,
coalesce(REPLACE(REPLACE(txtMonitorPlan, CHAR(13), ''), CHAR(10), ''),'') as txtMonitorPlan,
coalesce(REPLACE(REPLACE(txtReason, CHAR(13), ''), CHAR(10), ''),'') as txtReason,
coalesce(respPersonA,'') as respPersonA,
coalesce(respPersonB,'') as respPersonB,
coalesce(respPersonC,'') as respPersonC,
coalesce(respPersonD,'') as respPersonD,
coalesce(respPersonE,'') as respPersonE,
coalesce(respPersonF,'') as respPersonF,
coalesce(respPersonG,'') as respPersonG,
coalesce(respPersonH,'') as respPersonH,
coalesce(respPersonI,'') as respPersonI,
coalesce(respPersonJ,'') as respPersonJ,
coalesce(respPersonK,'') as respPersonK,
coalesce(respPersonL,'') as respPersonL,
coalesce(respPersonM,'') as respPersonM,
coalesce(respPersonN,'') as respPersonN,
coalesce(respPersonO,'') as respPersonO,
coalesce(respPersonP,'') as respPersonP,
coalesce(itemRequiredA,'No') as itemRequiredA,
coalesce(itemRequiredB,'No') as itemRequiredB,
coalesce(itemRequiredC,'No') as itemRequiredC,
coalesce(itemRequiredD,'No') as itemRequiredD,
coalesce(itemRequiredE,'No') as itemRequiredE,
coalesce(itemRequiredF,'No') as itemRequiredF,
coalesce(itemRequiredG,'No') as itemRequiredG,
coalesce(itemRequiredH,'No') as itemRequiredH,
coalesce(itemRequiredI,'No') as itemRequiredI,
coalesce(itemRequiredJ,'No') as itemRequiredJ,
coalesce(itemRequiredK,'No') as itemRequiredK,
coalesce(itemRequiredL,'No') as itemRequiredL,
coalesce(itemRequiredM,'No') as itemRequiredM,
coalesce(itemRequiredN,'No') as itemRequiredN,
coalesce(itemRequiredO,'No') as itemRequiredO,
coalesce(itemRequiredP,'') as itemRequiredP,
coalesce(REPLACE(REPLACE(txtotherOItem, CHAR(13), ''), CHAR(10), ''),'') as txtotherOItem,
coalesce(REPLACE(REPLACE(txtotherPItem, CHAR(13), ''), CHAR(10), ''),'') as txtotherPItem,
coalesce(REPLACE(REPLACE(Comments, CHAR(13), ''), CHAR(10), ''),'') as Comments,
coalesce(LastModDate,'') as LastModDate,
coalesce(LastModBy,'') as LastModBy,
coalesce(formVersion,'V1') as formVersion,
coalesce(approverPMName,'') as approverPMName,
coalesce(approverPMADName,'') as approverPMADName,
coalesce(approverPMEmail,'') as approverPMEmail,
coalesce(approverPMApproveDate,'') as approverPMApproveDate,
coalesce(approverBULName,'') as approverBULName,
coalesce(approverBULADName,'') as approverBULADName,
coalesce(approverBULEmail,'') as approverBULEmail,
coalesce(approverBULApproveDate,'') as approverBULApproveDate,
coalesce(approverCFOName,'') as approverCFOName,
coalesce(approverCFOADName,'') as approverCFOADName,
coalesce(approverCFOEmail,'') as approverCFOEmail,
coalesce(approverCFOApproveDate,'') as approverCFOApproveDate,
coalesce(approverCEOName,'') as approverCEOName,
coalesce(approverCEOADName,'') as approverCEOADName,
coalesce(approverCEOEmail,'') as approverCEOEmail,
coalesce(approverCEOApproveDate,'') as approverCEOApproveDate,
coalesce(approverPMTitle,'') as approverPMTitle,
coalesce(approverBULTitle,'') as approverBULTitle,
coalesce(approverCFOTitle,'') as approverCFOTitle,
coalesce(approverCEOTitle,'') as approverCEOTitle,
coalesce(emRetain,'') as emRetain,
coalesce(Taxid,'') as Taxid,
coalesce(CreatedByADName,'') as CreatedByADName,
coalesce(approverAdd1Title,'') as approverAdd1Title,
coalesce(approverAdd1Name,'') as approverAdd1Name,
coalesce(approverAdd1ADName,'') as approverAdd1ADName,
coalesce(approverAdd1Email,'') as approverAdd1Email,
coalesce(approverAdd1ApproveDate,'') as approverAdd1ApproveDate,

coalesce(approverAdd2Title,'') as approverAdd2Title,
coalesce(approverAdd2Name,'') as approverAdd2Name,
coalesce(approverAdd2ADName,'') as approverAdd2ADName,
coalesce(approverAdd2Email,'') as approverAdd2Email,
coalesce(approverAdd2ApproveDate,'') as approverAdd2ApproveDate,

coalesce(approverAdd3Title,'') as approverAdd3Title,
coalesce(approverAdd3Name,'') as approverAdd3Name,
coalesce(approverAdd3ADName,'') as approverAdd3ADName,
coalesce(approverAdd3Email,'') as approverAdd3Email,
coalesce(approverAdd3ApproveDate,'') as approverAdd3ApproveDate,

coalesce(approverAdd4Title,'') as approverAdd4Title,
coalesce(approverAdd4Name,'') as approverAdd4Name,
coalesce(approverAdd4ADName,'') as approverAdd4ADName,
coalesce(approverAdd4Email,'') as approverAdd4Email,
coalesce(approverAdd4ApproveDate,'') as approverAdd4ApproveDate,

coalesce(approverAdd5Title,'') as approverAdd5Title,
coalesce(approverAdd5Name,'') as approverAdd5Name,
coalesce(approverAdd5ADName,'') as approverAdd5ADName,
coalesce(approverAdd5Email,'') as approverAdd5Email,
coalesce(approverAdd5ApproveDate,'') as approverAdd5ApproveDate,

coalesce(approverAdd6Title,'') as approverAdd6Title,
coalesce(approverAdd6Name,'') as approverAdd6Name,
coalesce(approverAdd6ADName,'') as approverAdd6ADName,
coalesce(approverAdd6Email,'') as approverAdd6Email,
coalesce(approverAdd6ApproveDate,'') as approverAdd6ApproveDate,
CASE When RTRIM(E.Status) = '' THen 'Open' Else E.Status End as Status,

coalesce(activeStatus,'') as activeStatus,
case
when approverAdd6Email > '' Then '10'
when approverAdd5Email > '' Then '09'
when approverAdd4Email > '' Then '08'
when approverAdd3Email > '' Then '07'
when approverAdd2Email > '' Then '06'
when approverAdd1Email > '' Then '05'
when approverCEOEmail > '' Then '04'
when approverCFOEmail > '' Then '03'
when approverBULEmail > '' Then '02'
when approverPMEmail > '' Then '01'
else  '00'
End as approverCount,
coalesce(nextApprover,'') as nextApprover,
PublicFolder + '\' + PublicSubFolder as docFolder,
coalesce(A.mailAddress,CreatedByADName) as CreatedByEmail,
coalesce(PostAward,'') as PostAward

from dbo.ExposureMitigation as E
left join Prequal as P
on PrequalID = P.ID
left join BBC_ADMAILUSER as A
on A.samAccountName = E.CreatedByADName
where Coalesce(activeStatus,'') <> 'I'
)


GO
