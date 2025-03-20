using namespace System.Collections.Generic

#Requires -Modules @{ModuleName="AWS_Tools_AddOns"; ModuleVersion="0.0.6"}
#Requires -Modules @{ModuleName="ImportExcel"; ModuleVersion="7.8.0"}

Param(
    [string]$OutputFileName,
    [string]$OutputFolder,
    [string]$AWSRegion,
    [switch]$Append,
    [pscredential]$Credential,
    [switch]$BootVolumeOnly,
    [string[]]$Include,
    [string[]]$Exclude,
    [switch]$UseDNSDomain
)

$ErrorActionPreference = "STOP"

$ServerList = [List[PsObject]]::New()

if ($AWSRegion) {
    Set-DefaultAWSRegion -Region $AWSRegion
}

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
        Select-Object @{Name="Date"; Expression={$_.Date}},
                      @{Name="Title"; Expression={$_.Title}},
                      @{Name="KB Article"; Expression={
                          if ($_.Title -match "KB\d+") { 
                              $matches[0]
                          } else {
                              "N/A"
                          }
                      }}
}

$StartRow = 2

$ExcelFile = "$OutputFolder$OutputFileName"
if ((Test-Path -Path $ExcelFile) -and (-not $Append)) {
    Remove-Item -Path $ExcelFile -Force
}

$worksheetName = "AWS Server Info"

# If append is specified get the number of rows in the worksheet and set the start row to this number + 2.
if ($Append) {
    [List[PSObject]]$Rows = Import-Excel -Path $ExcelFile -WorksheetName $worksheetName -StartRow 2
    $ServerList.AddRange($Rows)
}

# Start the excel workbook
$excel = Export-Excel -Path $ExcelFile -WorksheetName $worksheetName -PassThru

# Get the EC2 Windows Instances

$InstanceList = Get-Ec2InstanceList | Where-Object {$_.Platform -like "Windows*" -and $_.InstanceState -eq 'Running'}

# filter the list by the include and exclude lists. Exclude takes president opver include.
$InstanceList = $InstanceList | Where-Object {$_.Name -notin $Exclude}

If ($Include) {
    $InstanceList = $InstanceList | Where-Object {$_.Name -in $Include}
}


foreach ($Instance in $InstanceList) {
    
    if ($InstanceList -is [array]) {
        Write-Progress -Activity $Instance.Name -PercentComplete (($InstanceList.IndexOf($Instance) / $InstanceList.Count) * 100)
    }

    # Get Volume information
    $Filter = @{
        name = 'attachment.instance-id'
        values = $Instance.InstanceId
    }
    $Volumes = Get-EC2Volume -Filter $Filter | Select-Object VolumeId,Encrypted, @{Name="Device"; Expression={$_.Attachments.device}}

    If ($BootVolumeOnly) {
        $Volumes = $Volumes | Where-Object {$_.Device -eq "/dev/sda1"}
    }

    try {
        # Set the CIm Session Options for SSL
        $CIMSessionOptions = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -UseSsl
        # Create the CIM Session
        $ComputerName = $Instance.Name
        if ($ComputerName.Contains(".")) {
            $ComputerName = $ComputerName.Substring(0, $ComputerName.IndexOf("."))
        }
        if ($UseDNSDomain) {$ComputerName += ".$env:USERDNSDOMAIN"}
        if ($Credential) {
            $CIMSession = new-CIMSession -ComputerName $ComputerName -SessionOption $CIMSessionOptions -Credential $Credential
        } else {
            $CIMSession = new-CIMSession -ComputerName $ComputerName -SessionOption $CIMSessionOptions
        }
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

    # Get Operating System INformation
    # First try to connect using SSL (the preferred method)
    try {
        $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem -CimSession $CIMSession -Property Caption, BuildNumber, Version | Select-Object Caption, BuildNumber, Version
    } catch {
        # now try using HTTP
        try {
            $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem -ComputerName $ComputerName -Property Caption, BuildNumber, Version | Select-Object Caption, BuildNumber, Version
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


    If ($BootVolumeOnly) {
        $OS = [PSCustomObject]@{
            Server = $ComputerName
            OSType = $OSInfo.Caption
            BuildNumber = $OSInfo.BuildNumber
            Version = $OSInfo.Version
            LastPatchDate = $LastPatchDate
            BootVolumeEncryption = $Volumes.Encrypted
        }

        $ServerList.Add($OS)
    } else {
        $OS = [PSCustomObject]@{
            OSType = $OSInfo.Caption
            BuildNumber = $OSInfo.BuildNumber
            Version = $OSInfo.Version
            LastPatchDate = $LastPatchDate
        }
    
        # write server table
        $tableName = "tbl_{0}" -f $Instance.Name
        $excel = $OS | Export-Excel   -ExcelPackage $excel `
                                -WorksheetName $worksheetName `
                                -StartRow $StartRow `
                                -StartColumn 1 `
                                -TableName $tableName `
                                -Title $ComputerName `
                                @titleParams `
                                -AutoSize `
                                -Numberformat Text `
                                -PassThru
        
        $StartRow += 2

        $tableName = "tbl_Volumes_{0}" -f $instance.Name
        $excel = $Volumes | Export-Excel -ExcelPackage $excel `
                                -WorksheetName $worksheetName `
                                -StartRow $StartRow `
                                -StartColumn 3 `
                                -TableName $tableName `
                                -Title "Volumes" `
                                @titleParams `
                                -AutoSize `
                                -Numberformat Text `
                                -PassThru

        $StartRow += ($Volumes.Count +2)
    }
}


If ($BootVolumeOnly) {
            # write server table
            $Tablename = "Servers"
            $excel = $ServerList.ToArray() | Export-Excel -ExcelPackage $excel `
            -WorksheetName $worksheetName `
            -TableName $tableName `
            -TableStyle Medium2 `
            -Title "Servers" `
            @titleParams `
            -AutoSize `
            -Numberformat Text `
            -PassThru    
}

# Format tables
# $excel.Workbook.Workbooksheet[$WorksheetName].Tables | ForEach-Object {
#     $_.Address | Set-ExcelRange @TableParams
# }

Close-ExcelPackage $excel -Show

$Failures | Select-Object Name, Message
