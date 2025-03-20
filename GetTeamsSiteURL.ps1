using namespace System.Collections.Generic
#requires -modules @{ModuleName = 'ExchangeOnlineManagement'; ModuleVersion='3.1.0'}

Param
(
    [string]$UserName
)
$ConInfo = Get-ConnectionInformation
if ((-not $ConInfo) -or ($ConInfo.Name -like 'ExchangeOnline*' -and $ConInfo.State -ne 'Connected')) {
    if (-not $Username) {
        $Username = Read-Host -Prompt "Enter you Microsoft 365 username:"
    }
    Connect-ExchangeOnline -UserPrincipalName $Username
}

$Results = [List[PsObject]]::New()

$OutputCSV="./TeamsSPOUrl_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"
$Result="" 

#Get Teams' site URL
#Get-UnifiedGroup –Filter {ResourceProvisioningOptions -eq "Team"} | Select DisplayName,SharePointSiteUrl,PrimarySMTPAddress,ManagedBy,AccessType,WhenCreated | Export-CSV $OutputCSV  -NoTypeInformation 
Get-UnifiedGroup –Filter {ResourceProvisioningOptions -eq "Team"} | ForEach-Object {
    $DisplayName =$_.DisplayName
    Write-Progress -Activity "Exported Teams count: $ExportedCount" "Currently Processing Team: $DisplayName" 
    $SharePointSiteURL=$_.SharePointSiteURL
    $PrimarySMTPAddress=$_.PrimarySMTPAddress
    $Managers=$_.ManagedBy
    $AccessType=$_.AccessType
    $WhenCreated=$_.WhenCreated
    $ManagedBy= ($Managers -join ", ")


    $Result = [PSCustomObject]@{
        'Team Name'=$Displayname
        'SharePoint Site URL'=$SharePointSiteURL
        'Primary SMTP Address'=$PrimarySMTPAddress
        'Managed By'=$ManagedBy
        'Access type'=$AccessType
        'Creation Time'=$WhenCreated
    } 
    $Results.Add($Result)        
}

#Open output file after execution
If($Results.Count -eq 0) {
    Write-Host No records found
} else {
    $Results.ToArray() | Export-CSV -Path $OutputCSV -IncludeTypeInformation
    if((Test-Path -Path $OutputCSV) -eq "True") {
        Write-Host `nThe Output file is available in $OutputCSV -ForegroundColor Green
    }
}
