#Requires -Modules @{ModuleName = "Smartsheet"; ModuleVersion = "1.0.0"}
#Requires -Modules @{ModuleName = "Meraki-API-V1"; ModuleVersion = "0.0.3"}
using namespace System.Collections.Generic

Param(
    [Parameter(Mandatory = $true)]
    [string]$SheetName,
    [string]$FolderId,
    [switch]$AllowClobber
)
<# 
$HeaderFormat = New-SmartSheetFormatString -bold 
$TitleFormat = New-SmartSheetFormatString -fontSize $SSFormat.FontSizes.14 -bold
 #>
$sheet = Get-Smartsheets | Where-Object {$_.Name -eq $SheetName}
if ($sheet) {
    if ($sheet -is [array]) {
        throw "There are multiple sheets with the name $SheetName. Cannot determine which sheet to use!"
    }
} else {
    if ($FolderId) {
        $Sheet = New-Smartsheet -SheetName $SheetName -Id $FolderId        
    } else {
        $Sheet = New-Smartsheet -SheetName $SheetName
    }
}

$Networks = Get-MerakiNetworks
#$Templates = Get-MerakiOrganizationConfigTemplates
<# 
$TemplateData = $Templates | foreach-Object {
    Write-Progress -Activity "Gathering Template VLANS" -Status $_.Name
    $Name = $_.Name
    $_ | Get-MerakiNetworkApplianceVLANS | Select-Object *, @{Name="Template"; Expression={$Name}}
}

$TemplateData | Select-Object Template, CIDR, MASK | `
                Export-SmartsheetRows  -sheetId $Sheet.id `
                                       -title "Templates" `
                                       -titleFormat $TitleFormat `
                                       -includeHeaders `
                                       -headerFormat $HeaderFormat
 #>
$VLANS = [List[PSObject]]::New()

foreach ($Network in $Networks) {
    Write-Progress -Activity "Gathering VLANS for Network" -Status "$($Network.Name)"
    $ApplianceVLANs = Get-MerakiNetworkApplianceVLANS -id $Network.Id -ErrorAction SilentlyContinue
    if ($ApplianceVLANs) {
        foreach ($ApplianceVLAN in $ApplianceVLANs) {
            Write-Progress -Activity "Gathering data for VLAN" -Status "$($ApplianceVLAN.Name)"
            $vlan = [PSCustomObject]@{
                NetworkName = $Network.Name
                VLAN = $ApplianceVLAN.Id
                Name = $ApplianceVLAN.Name
                Subnet = $ApplianceVLAN.Subnet
            }

            $VLANS.Add($vlan)
        }
    }

    # Is there a stack

    $Stacks = Get-MerakiNetworkSwitchStacks -networkId $Network.Id
    if ($Stacks) {
        foreach ($Stack in $Stacks) {
            Write-Progress -Activity "Gathering Stack Interfaces" -Status "$($Stack.Name)"
            $Interfaces = Get-MerakiSwitchStackRoutingInterfaces -networkId $Network.Id -Id $Stack.Id -ErrorAction SilentlyContinue
            if ($Interfaces) {
                foreach ($Interface in $Interfaces) {
                    Write-Progress -Activity "Gathering VLANS for interface" -Status "$($Interface.name)"
                    $vlan = [PSCustomObject]@{
                        NetworkName = "-"
                        VLAN = $Interface.vlanId
                        Name = $Interface.Name
                        Subnet = $Interface.Subnet
                    }

                    $VLANS.Add($vlan)
                }
            }
        }
    }
    #Switches
    $Switches = (Get-MerakiNetworkDevices -id $Network.Id).Where({$_.model -like "MS*"})
    foreach ($switch in $switches) {
        Write-Progress -Activity "Gathering Switch Interfaces" -Status "$($switch.Name)"
        if ($Stacks) {
            foreach ($stack in $Stacks) {
                if ($Stack.serials -notcontains $switch.serial) {
                    $Interfaces = Get-MerakiSwitchRoutingInterfaces -serial $switch.serial -ErrorAction SilentlyContinue
                    if ($Interfaces) {
                        foreach ($Interface in $Interfaces) {
                            Write-Progress -Activity "Gathering vlans for interface" -Status "$($Interface.name)"
                            $vlan = [PSCustomObject]@{
                                NetworkName = "-"
                                VLAN = $Interface.vlanId
                                Name = $Interface.Name
                                Subnet = $Interface.Subnet                
                            }

                            $VLANS.Add($vlan)
                        }
                    }
                }
            }
        } else {
            $Interfaces = Get-MerakiSwitchRoutingInterfaces -serial $Switch.serial
            if ($Interfaces) {
                foreach ($Interface in $Interfaces) {
                    Write-Progress -Activity "Gathering vlans for interface" -Status "$($Interface.name)"
                    $vlan = [PSCustomObject]@{
                        NetworkName = "-"
                        VLAN = $Interface.vlanid
                        Name = $Interface.name
                        Subnet = $Interface.Subnet
                    }
                    $VLANS.Add($vlan)
                }
            }
        }
    }                                                    
}
# $VLANS.ToArray() | Export-SmartsheetRows    -sheetId $Sheet.id `
#                                             -blankRowAbove `
#                                             -title "Networks" `
#                                             -titleFormat $TitleFormat `
#                                             -includeHeaders `
#                                             -headerFormat $HeaderFormat `

$VLANS.ToArray() | Update-Smartsheet -sheetId $sheet.Id 

Write-Host "Completed!"                                            