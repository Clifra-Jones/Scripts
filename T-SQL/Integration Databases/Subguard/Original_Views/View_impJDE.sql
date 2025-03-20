SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
ALTER  VIEW [dbo].[VIEW_impJDE] as
Select Y.PVID as VendorNo, V_Name as VendorName, Coalesce(V_TaxID,'') as VendorTaxID,
impCurrbal as CurrBal , Coalesce(Overall, 0) as SurveyRank , Coalesce(PrjCnt,0) as PrjCnt, Coalesce(CmpltCnt,0) as CmpltCnt -- added Mar 14,2012

from
-- Added Case statement in sum to include curr balance when shown to be less than 100% complete.
        -- use the Contracts that have been translated to ParentVID
        (Select   Sum(Case V_PCNTCMPLT WHEN 100 Then 0 Else V_OpenAmt END) as impCurrBal,  PVID
        from VIEW_ContractsByParentVID

        Group by PVID) as  Y
inner join
        -- Get the name, JDE TaxID
        (Select PVID, MAX(V_Name) as V_Name, MAX(V_TaxID) as V_TaxID from VIEW_ContractsByParentVID group by PVID) as N
        on Y.PVID = N.PVID
Left join
        -- The OVERALL Value is in the ParentVendorID form
        View_SurveyResponse_VID_Class as SRT
        on SRT.JDEVendorID = Y.PVID

Left join
        -- include a count of contracts/projects with an open balance.
        (select PVID, Count(*) as PrjCnt from VIEW_ContractsByParentVID where V_PCNTCMPLT < 100
        group by PVID) as P
        on P.PVID = Y.PVID

--  Added this Completed Count of Contracts/Projects on Mar 14, 2012
Left join
        -- include a count of contracts/projects that are complted.
        (select PVID, Count(*) as CmpltCnt from VIEW_ContractsByParentVID where V_PCNTCMPLT = 100
        group by PVID) as CM
        on CM.PVID = Y.PVID
GO
