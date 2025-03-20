#Requires -Modules Smartsheet
$Servers = (Get-SmartSheet -Name "Zabbix Agent Versions").ToArray() | Where-Object {$_.Technician -eq "Cliff"}

foreach ($Server in $Servers) {
    $HostName = $Server.HostName.Split(".")[0]
    If (Test-Path "\\$hostname\C$") {
        if (-not (Test-Path "\\$HostName\C$\scripts\Clean-ArchivedLogs.ps1")) {
            if (Test-Path "\\$hostname\c$\Scripts") {
                if (-not ((Get-Item -Path "\\$hostName\c$\Scripts") -is [System.IO.DirectoryInfo])) {
                    Remove-Item -Path "\\$hostname\C$\Scripts" -Force
                }        
            }
            if (-not (Test-Path "\\$HostName\C$\Scripts")) {
                New-Item -ItemType Directory -Path "\\$HostName\C$\Scripts"
            }
            Copy-Item -Path "\\awsfsxe1file\Staging\Scripts\*.*" -Destination "\\$HostName\c$\Scripts" 
        }
    }
}