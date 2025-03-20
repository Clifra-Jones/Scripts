using namespace System.Collections.Generic

$Custodians = import-csv ./Custodians.csv

$Holds = [List[PsObJect]]::New()

Foreach ($Custodian in $Custodians) {
    $InPlaceHolds = (Get-Mailbox $Custodian.email).InPlaceHolds
    foreach ($InPlaceHold in $InPlaceHolds) {
        If ($InPlaceHold.StartsWith("UniH")) {
            $Guid = $InPlaceHold.SubString(4)
            $CaseHold = Get-CaseHoldPolicy $Guid
            $CaseName = (Get-ComplianceCase $CaseHold.CaseId).Name
            $Hold = [PSCustomObject]@{
                Custodian = $Custodian.Name
                Type = 'eDiscovery'
                Case = $CaseName
                CaseHold = $CaseHold.Name
                Workloads = $CaseHold.Workload
                Enabled = $CaseHold.Enabled
                Mode = $CaseHold.Mode
            }
            $Holds.Add($Hold)
        }
    } 
}

$HoldsByGroup = $Holds | Group-Object -Property Custodian

$excel = Export-Excel -Path '.\LegalHoldCases.xlsx' -PassThru

$StartRow = 1

$titleParams = @{
    TitleBold=$true;
    TitleSize=12;
}

foreach ($HoldGroup in $HoldsByGroup) {
    $Title = $HoldGroup.Name
    $HoldGroup.Group | Export-Excel -ExcelPackage $excel `
        -StartRow $StartRow `
        -StartColumn 1 `
        -Title $Title `
        @titleParams        
        -AutoSize `
        -NumberFormat Test `
        -PassThru    
}
