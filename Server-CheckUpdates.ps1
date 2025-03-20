# Author: Cliff Williams
# Company: Balfour Beatty US
# Revised: 6/24/2020
#
# Synopsys: Check for available Windows Updates on remove server and optionally install them.
#
# Parameters:
#   ComputerName: Name or IP of remote computer
#   InputFile: A list of computernames to check. Column heading must be "Name"
#   InstallUpdate: Switch to install found updates
#   ScheduleReboot: switch to schedule reboot. If omitted
#   MicrosoftUpdate: Search for al update. If omitted only Windows Updates are searched.

Param (
    [string]$ComputerName,
    [string]$InputFile,
    [Parameter(ParameterSetName='install',Mandatory=$false)][switch]$InstallUpdates,
    [Parameter(ParameterSetName="reboot",Mandatory=$false)][switch]$ScheduleReboot,
    [Parameter(ParameterSetName="reboot",Mandatory=$true)]$RebootTime,
    [switch]$MicrosoftUpdates
)

function Get-Updates ($ComputerName, $Parameters) {
    $Updates = Get-WindowsUpdate @Parameters
    Return $Updates
}

$Parameters = @{}

If ($installUpdates) {
    $Parameters.Add("Install", $true)

    If ($ScheduleReboot) {
        $Parameters.Add("ScheduleReboot", $RebootTime) 
    } Else {
        $Parameters.Add("IgnoreReboot", $true)
    }

    $Parameters.Add("Confirm", $false)
}

If ($MicrosoftUpdates) {
    $Parameters.add("MicrosoftUpdate", $true)
}

$report = New-Object System.Collections.Generic.List[PSObject]

If ($InputFile) {
    $Computers = import-csv $InputFile
    foreach($computer in $Computers) {
        "Checking computer: {0}" -f $computer.name
        if (-not $Parameters.ContainsKey("Computer")) {
            $Parameters.add("Computer", $Computer.Name)
        } else {
            $Parameters["Computer"] = $Computer.Name
        }
        $Updates = Get-Updates $Computer.Name $Parameters
        foreach ($Update in $Updates) {
            $Update = [PSCustomObject]@{
                Computer = $Computer.Name
                KB = $Update.KB
                Title = $Update.Title
            }
            $report.add($Update)
        }
    }
} Else {
    $Updates = get-Updates $ComputerName $Parameters
    foreach ($Update in $Updates) {
        $MSUpdate = [PSCustomObject]@{
            Computer = $ComputerName
            KB = $Update.KB
            Title = $Update.Title
        }
        $report.add($MSUpdate)
    }
}

$report.ToArray() | export-csv -NoTypeInformation "WindowsUpdateReport.csv"




