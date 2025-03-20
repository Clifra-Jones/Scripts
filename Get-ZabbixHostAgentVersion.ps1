using namespace System.Collections.Generic
#Requires -Modules PSZabbix, SmartSheet

$HostList = [List[PSObject]]::New()
$WindowsTemplateId = '10081'
$LinuxTemplateId = '10001'

$ZabbixHosts = Get-ZabbixHost -excludeDisabled -includeParentTemplates

foreach ($ZabbixHost in $ZabbixHosts) {
    $i = $ZabbixHosts.IndexOf($ZabbixHost)
    $PC = (($i / $ZabbixHosts.Length ) * 100) 
    $Hostname = $ZabbixHost.host
    if ($HostName.ToLower().endsWith("bbc.local")) {
        $Technician = "Cliff"
    } elseif ($Hostname.ToLower().endsWith("bbcgrp.local")) {
        $Technician = "Brendan"
    } else {
        $Technician = " "
    }
    Write-Progress -Activity "Getting Zabbix Agent Version" -Status "Host: $Hostname" -PercentComplete $PC
    if ($ZabbixHost.ParentTemplates.templateId.Contains($WindowsTemplateId)) {
        $OS = "Windows"
    } elseIf($ZabbixHost.ParentTemplates.templateId.Contains($LinuxTemplateId)) {
        $OS = "Linux"
    } else {
        $OS = "Unknown"
    }
    $Item = Get-ZabbixItems -hostId $ZabbixHost.hostId | Where-object {$_.Key_ -eq 'agent.version'}
    if ($item) {
        $History = Get-ZabbixHistory -hostId $ZabbixHost.HostId -itemid $Item.itemId -historyType:character -limit 1
        $AgentVersion = $History.value
    } else {
        $AgentVersion = "Not installed"
    }
    $HostAgent = [PsCustomObject]@{
        HostName = $Hostname
        OperatingSystem = $OS
        CurrentAgentVersion = $AgentVersion
        Upgraded = $False
        NewAgentVersion = " "
        Technician = $Technician
    }
    $HostList.Add($HostAgent)
}

$HostList.ToArray() | Export-SmartSheet -SheetName "Zabbix Agent Versions"
