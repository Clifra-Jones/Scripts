SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE View [dbo].[VIEW_Precon_Export] as (
Select
SubmittedTaxid
,vendor
,IsNull(Replace(Replace(DBAQuestion,Char(13),';'),Char(10),''),'') as DBA
 ,CASE WHEN Len(ExpirationDate)  > 0  THEN convert(varchar,ExpirationDate,101) ELSE '' END as ExpirationDate
,IsNull(BondSPL,'') as Subc_BondLimit
, SingleAmt as BBC_SingleLimit
, AggregateAmt as BBC_AggregateLimit
,CASE IsNumeric(JDE.CurrBal) WHEN 1 Then JDE.Currbal ELSE 0 END  AS BBC_OpenBal
,status
,        IsNull(P.EMR_Year_1,'') as Year1
,               IsNull(P.EMR_Rate_1, '') as EMR1
,               IsNull(F.OshaFatalyr1, '') as Fatal1
,               IsNull(F.oshaTRIRyr1,  '') as TRIR1
,               IsNull(F.oshaDARTyr1, '') as DART1
,        IsNull(P.EMR_Year_2,  '') as Year2
,               IsNull(P.EMR_Rate_2,  '') as EMR2
,               IsNull(F.OshaFatalyr2,  '') as Fatal2
,               IsNull(F.oshaTRIRyr2,  '') as TRIR2
,               IsNull(F.oshaDARTyr2, '') as  DART2
,        IsNull(P.EMR_Year_3,  '') as Year3
,               IsNull(P.EMR_Rate_3,  '') as EMR3
,               IsNull(F.OshaFatalyr3,  '') as Fatal3
,               IsNull(F.oshaTRIRyr3,  '') as TRIR3
,               IsNull(F.oshaDARTyr3, '') as DART3
,        vendorAddr
, VendorCity
, VendorState
, VendorZip
, DateLastMod
, 'P' as Srce

From Prequal as P
LEFT JOIN VIEW_impJDE as JDE
ON IsNull(P.CurrBalVID,P.VendorNo) = JDE.VendorNo

Left Join Q_financialSafety as F
on F.Recid = P.QNLink
Left join Q_TA_DBAQuestion as TAQ
on TAQ.RECID = P.QnLink
Where Upper( P.Status) <> 'INACTIVE'

Union

Select submittedTaxID
, vendor
,IsNull(Replace(Replace(DBAQuestion,Char(13),';'),Char(10),''),'') as DBA
,'NA' as ExpirationDate
,IsNull(BondSPL,'') as Subc_BondLimit
, 0 as BBC_SingleLimit
, 0as BBC_AggregateLimit
,Coalesce(JDE.CurrBal,0) as BBC_OpenBal
,'NoPrequal' as status,
        IsNull(F.EMRYr1, '') as Year1,
                IsNull(F.EMRNumb1, '') as EMR1,
                IsNull(F.OshaFatalyr1, '') as Fatal1,
                IsNull(F.oshaTRIRyr1, '') as TRIR1,
                IsNull(F.oshaDARTyr1,'') as DART1,
        IsNull(F.EMRYr2, '') as Year2,
                IsNull(F.EMRNumb2, '') as EMR2,
                IsNull(F.OshaFatalyr2, '') as Fatal2,
                IsNull(F.oshaTRIRyr2, '') as TRIR3,
                IsNull(F.oshaDARTyr2,'') as DART2,
        IsNull(F.EMRYr3, '') as Year3,
                IsNull(F.EMRNumb3, '') as EMR3,
                IsNull(F.OshaFatalyr3, '') as Fatal3,
                IsNull(F.oshaTRIRyr3, '') as TRIR3,
                IsNull(F.oshaDARTyr3,'') as DART3,
        VendorAddr
, VendorCity
, VendorState
, VendorZip
, QuestionnaireDate
 , 'T' as Srce

From T2Prequal as Q
LEFT JOIN VIEW_impJDE as JDE
ON Coalesce(Q.VendorNo,0) = JDE.VendorNo
Left Join Q_financialSafety as F
on F.Recid = Q.QNLINK
Left join Q_TA_DBAQuestion as TAQ
on TAQ.RECID = Q.QNLINK
Where isNull(RecordStatus,'NA') <> 'Void'

)
GO
