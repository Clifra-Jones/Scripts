using namespace System.Collections.Generic

#Requires -Modules "AWS_TOOLS_AddOns","ImportExcel"

Param(
    [string]$SearchBase,
    [string]$OutputFolder,
    [string]$OutputFileName,
    [switch]$Append,
    [switch]$BootVolumeOnly,
    [string[]]$Include,
    [string[]]$Exclude,
    [switch]$UseDNSDomain
)

$ErrorActionPreference = "STOP"

$ServerList = [List[PSObject]]::New()

if (-not $OutputFolder) {
    $OutputFolder = $PSScriptRoot
}

If ((-not $OutputFolder.EndsWith("/")) -or (-not $OutputFolder.EndsWith("\")) ) {
    $OutputFolder += "/"
}

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

$ExcelFile = "$OutputFolder$OutputFileName"
if ((Test-Path -Path $ExcelFile) -and (-not $Append)) {
    Remove-Item -Path $ExcelFile -Force
}

$worksheetName = "AD Server Info"

# Start the excel workbook
$excel = Export-Excel -Path $ExcelFile -WorksheetName $worksheetName -PassThru

# If append is specified get the number of rows in the worksheet and set the start row to this number + 2.
if ($Append) {
    [List[PSObject]]$Rows = Import-Excel -Path $ExcelFile -WorksheetName $worksheetName -StartRow 2
    $ServerList.AddRange($Rows)
}
$Filter = {OperatingSystem -like "*Server*"}

$Computers = Get-ADComputer -Filter $Filter -Properties OperatingSystem -SearchBase $SearchBase -SearchScope Subtree -server $env:USERDNSDOMAIN

$Computers = $Computers | Where-Object {$_.Name -notin $Exclude}

If ($Include) {
    $Computers = $Computers | Where-Object {$_.Name -in $Include}
}

foreach ($Computer in $Computers) {
    Write-Progress -Activity $Computer.Name -PercentComplete (($Computers.IndexOf($Computer)/$Computers.count) * 100)
    if ($UseDNSDomain) {
        $Computername = $Computer.Name + ".$env:USERDNSDOMAIN"
    } else {
        $Computername = $Computer.Name
    }

    # Test Connection
    if (-not (Test-Connection $Computername -ErrorAction SilentlyContinue)) {
        Write-Host "Server $Computername not available!" -ForegroundColor Red
        Continue
    }

    try {
        $cso = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -UseSsl
        $cs = New-CimSession -ComputerName $Computername -SessionOption $cso
    } catch {
        throw "Failed fo connect to $Computername using https: $($_.Exception.Message)"
    }

    try {
        $OSInfo = Get-CimInstance -ClassName Win32_OperatingSystem -Property Caption, BuildNumber, Version -CimSession $cs
    }catch {
        throw "cannot connect to remote server $Computername"
    }

    # Get Update Information
    try {
        $PSO = New-PSSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck
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
        BootVolumeEncryption = "False"
    }

    $ServerList.Add($OS)
    
}

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

Close-ExcelPackage $excel -Show