using namespace System.Collections.Generic

#Requires -Modules "Az"

Param(
    [string]$OutputFileName,
    [string]$OutputFolder,
    [PSCredential]$Credential,
    [switch]$BootVolumeOnly,
    [string[]]$Include,
    [string[]]$Exclude,
    [string]$UseDnsDomain
)

$ErrorActionPreference = "STOP"

$ServerList = [List[PSObject]]::New()

if (-not $OutputFolder) {
    $OutputFolder = $PSScriptRoot
}

If ((-not $OutputFolder.EndsWith("/")) -or (-not $OutputFolder.EndsWith("\")) ) {
    $OutputFolder += "/"
}

$Failures = [List[PsObject]]::New()

# excel table formatting
$titleParams = @{
    TitleBold=$true
    TitleSize=12
}

$TableParams = @{
    BorderColor="black"
    BorderRight="thin"
    BorderLeft="thin"
    BorderTop="thin"
    BorderBottom="thin"
    FontSize=9
}

$ScriptBlock = {
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()

    $HistoryCount = $UpdateSearcher.GetTotalHistoryCount()
    $Updates = $UpdateSearcher.QueryHistory(0, $HistoryCount)
    
    $Updates | 
        Where-Object { $_.Operation -eq 1 } |  # 1 means 'Installation'
        Select-Object -First 1 @{Name="Date"; Expression={$_.Date}},
                      @{Name="Title"; Expression={$_.Title}},
                      @{Name="KB Article"; Expression={
                          if ($_.Title -match "KB\d+") { 
                              $matches[0]
                          } else {
                              "N/A"
                          }
                      }} | ConvertTo-Json
}

$StartRow = 2

$ExcelFile = "$OutputFolder$OutputFileName"
if ((Test-Path -Path $ExcelFile) -and (-not $Append)) {
    Remove-Item -Path $ExcelFile -Force
}

$worksheetName = "Azure Server Info"

# Start the excel workbook
$excel = Export-Excel -Path $ExcelFile -WorksheetName $worksheetName -PassThru

$VMs = Get-AzVm -Status | Where-Object {$_.OSName -like "*Windows*" -and $_.PowerState -eq "VM Running"}

$VMs = $VMs | Where-Object {$_.Name -notin $Exclude}

if ($Include) {
    $VMs = $VMs | Where-Object {$_.Name -in $Include}
}

foreach ($VM in $VMs) {
    $OSDiskEncryptionStatus = (Get-AzVMDiskEncryptionStatus -ResourceGroupName $VM.ResourceGroupName -VMName $VM.Name).OSVolumeEncrypted
    $OSName = $VM.OSName
    $OSVersion = $VM.OsVersion
    $BuildNumber = $VM.OsVersion.Split(".")[2]

    try {
        $result = Invoke-AzVMRunCommand -ResourceGroupName $VM.ResourceGroupName -VMName $vm.Name -CommandId "RunPowershellScript" -ScriptString $ScriptBlock
        If ($result.value[1].message -like "Exception*") {
            $LastUpdateDate = "N/A"
        } else {
            $LastUpdate = $result.Value.message | ConvertFrom-Json
            $LastUpdateDate = $LastUpdate.Date.value
        }
    } catch {
        Throw "$($Vm.Name): $_.Exception.Message"
    }

    $os = [PSCustomObject]@{
        Server = $VM.Name
        OSType = $OSName
        BuildNumber = $BuildNumber
        Version = $OSVersion
        LastPatchDate = $LastUpdateDate
        BootVolumeEncryption = $OSDiskEncryptionStatus
    }

    $ServerList.Add($OS)
}

$Excel = $ServerList | Export-Excel -ExcelPackage $excel `
                        -WorksheetName $worksheetName `
                        -TableName "AzureServers" `
                        -TableStyle Medium2 `
                        -Title "Azure Servers" `
                        @titleParams `
                        -AutoSize `
                        -Numberformat TEXT `
                        -PassThru

Close-ExcelPackage -ExcelPackage $excel
