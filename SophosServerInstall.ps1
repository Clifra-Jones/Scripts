Add-PSSnapin Quest.ActiveRoles.ADManagement
$Servers = Get-QADComputer -SearchRoot 'bbiius.net/Companies' -OSName "*server*"

foreach ($server in $Servers) {
    if (Ping-Host -Hostname $Server.Name) {
        "$($Server.Name) is alive"
        $Products = Get-WmiObject -ComputerName $Server.Name -Class Win32_Product | Where-Object {$_.Name -like "*Sophos*"}
        if (!($products)) {
            "$($Server.Name) does not has Sophos"
            PsExec.exe "\\$($Server.Name)" -c ".\SophosServerSetup.exe" --quiet
        }
    }
}