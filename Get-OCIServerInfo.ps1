using namespace System.Collections.Generic

#Requires -Modules OCI.PSmodules, ImportExcel

Param(
    [string]$OutputFileName,
    [string]$OutputFolder,
    [PSCredential]$Credential,
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
                      }}
}

$ExcelFile = "$OutputFolder$OutputFileName"
if ((Test-Path -Path $ExcelFile) -and (-not $Append)) {
    Remove-Item -Path $ExcelFile -Force
}

$worksheetName = "ACI Server Info"

# Start the excel workbook
$excel = Export-Excel -Path $ExcelFile -WorksheetName $worksheetName -PassThru

$Instances = Get-OCIComputeInstancesList | Where-Object {$_.LifeCycleState -eq "Running"}

$Instances = $Instances | Where-Object {$_.DisplayName -notin $Exclude}

If ($Include) {
    $Instances = $Instances | Where-Object {$_.DisplayName -in $Include}
}

Foreach($INstance in $Instances) {
    $Image = Get-OCIComputeImage -ImageId $Instance.ImageId
    if ($Image.OperatingSystem -ne 'Windows') {
        Continue
    }

    If ($Instance.DisplayName -like "*-tgt*") {
        $ComputerName = $Instance.DisplayName.Substring(0, $Instance.DisplayName.IndexOf("-")) #.replace("-tgt*","")
    } else {
        $ComputerName = $Instance.DisplayName
    }

    If ($ComputerName.Contains("-")) {
       $Computername = $ComputerName.Replace("-","")
    }
    try {
        # Set the CIm Session Options for SSL
        $CIMSessionOptions = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -UseSsl
        # Create the CIM Session
        if ($UseDnsDomain) {{$ComputerName += ".$env:USERDNSDOMAIN"}}
        $CIMSession = new-CIMSession -ComputerName $ComputerName -SessionOption $CIMSessionOptions 
    } catch {
        Write-Host "Cannot connect to host server $ComputerName using SSL. Trying HTTP"
        $Failure = [PSCustomObject]@{
            Name = $Instance.Name
            Message = $_.Exception.Message
        }
        $Failures.Add($Failure)
        try {
            $CIMSession = New-CimSession -ComputerName $ComputerName
        } catch {
            Write-Host "Cannot connect to host server $ComputerName using HTTP."
            $Failure = [PSCustomObject]@{
                Name = $ComputerName
                Message = $_.Exception.Message
            }
            $Failures.Add($Failure)
            Continue
        }
    }
    try {
        $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $CIMSession -Property Caption, BuildNumber, Version | Select-Object Caption, BuildNumber, Version
    } catch {
        # now try using HTTP
        try {
            $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $Instance.Name -Property Caption, BuildNumber, Version | Select-Object Caption, BuildNumber, Version
        } catch {
            Write-Host "Cannot connect to remove server $ComputerName"
            $Failure = [PSCustomObject]@{
                Name = $ComputerName
                Message = $_.Exception.Message
            }
            $Failures.Add($Failure)
            Continue
        }
    }
 # Get Update Information
    try {
        $PSO = New-PSSessionOption -SkipCACheck -SkipCNCheck
        $PS = New-PSSession -ComputerName $ComputerName -SessionOption $PSO -UseSSL
        $LastPatchDate = (Invoke-Command -Session $PS -ScriptBlock $ScriptBlock | Sort-Object -Property Date -Descending | Select-Object -First 1).Date
    } catch {
        Throw "$($Instance.Name), $($_.Exception.Message)"
    }


    $OS = [PSCustomObject]@{
        Server = $ComputerName
        OSType = $OSInfo.Caption
        BuildNumber = $OSInfo.BuildNumber
        Version = $OSInfo.Version
        LastPatchDate = $LastPatchDate
        BootVolumeEncryption = "True"
    }

    $ServerList.Add($OS)
}


# write server table
$TableName = "Servers"
$excel = $ServerList.ToArray() | Export-Excel -ExcelPackage $excel `
-WorksheetName $worksheetName `
-TableName $TableName `
-TableStyle Medium2 `
-Title "Servers" `
@titleParams `
-AutoSize `
-Numberformat Text `
-PassThru    


# Format tables
# $excel.Workbook.Workbooksheet[$WorksheetName].Tables | ForEach-Object {
#     $_.Address | Set-ExcelRange @TableParams
# }

Close-ExcelPackage $excel

$Failures | Select-Object Name, Message

Write-Host "Completed" -ForegroundColor Yellow

