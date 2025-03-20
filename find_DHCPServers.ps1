Add-PSSnapin Quest.ActiveRoles.ADManagement
Import-Module MyTools
$DCsWithDHCP = $null
$DCsWithDHCP = @()
$ServersWithDHCP = $null
$ServersWithDHCP = @()

$OutFile = 'DHCPServers.txt'
$DCs =  Get-QADComputer -SearchRoot 'bbiius.net/Domain Controllers' 
foreach($DC in $DCs) {
    $DC.Name
    If (Ping-Host -Hostname $DC.name) {
        $services = Get-Service -ComputerName $DC.name
        If ($services.where({$_.Name -eq "DHCPServer"})){
           $DCsWithDHCP += $DC
        }
    }
}
foreach ($DC in $DCsWithDHCP) {
    $DC.name | Out-File -FilePath $OutFile -Append
    Get-DhcpServerv4Scope -ComputerName $dc.name | Out-File $OutFile -Append
}

$servers = Get-QADComputer -SearchRoot 'bbiius.net/Companies' | Where-Object {$_.OSName -Like "*Server*"}
ForEach ($Server in $Servers) {
    $Server.name
    if (Ping-Host -Hostname $Server.name) {
        $services=$null
        $services = Get-Service -ComputerName $server.name
        if ($services.where({$_.Name -eq "DHCPServer"})) {
            $ServersWithDHCP += $Server
        }
    }
}
foreach ($server in $serversWithDHCP) {
    $server.name | Out-File -FilePath $OutFile -Append
    Get-DhcpServerv4Scope -ComputerName $server.name | Out-file $OutFile -Append
}

