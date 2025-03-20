Param(
    $outputFolder,
    $FileName
)


$titleParams = @{
    TitleBold=$true;
    TitleSize=12;
}

$TableParams = @{
BorderColor="black";
BorderRight="thin";
BorderLeft="thin";
BorderTop="thin";
BorderBottom="thin";
FontSize=9
}

$Worksheet = "Subnets"
$StartRow = 1
$StartColumn = 1
$document = "{0}/{1}" -f $outputFolder, $FileName
$excel = Export-Excel -Path $document -Worksheet $WorkSheet -PassThru

$Networks = Get-MerakiNetworks
$Templates = Get-MerakiOrganizationConfigTemplates

#Document Templates
$TemplateData = $Templates | foreach-Object {
    $Name = $_.Name
    $_ | Get-MerakiNetworkApplianceVLANS | Select-Object *, @{Name="Template"; Expression={$Name}}
}

$excel = $TemplateData | Select-Object Template, CIDR, MASK | Export-Excel -ExcelPackage $excel -WorksheetName $Worksheet `
                                                                    -StartRow $StartRow -StartColumn $StartColumn `
                                                                    -TableName "Templates" -Title "Templates" @titleParams `
                                                                    -autoSize -NumberFormat Text -PassThru

$StartRow += $TemplateData.Count + 3                                                                    

Class VLAN {
    [string]$NetworkName
    [String]$VLAN
    [string]$Name
    [String]$Subnet
}                                                                    

$VLANS = New-Object System.Collections.Generic.List[PSObject]

foreach ($Network in $Networks) {
    #Get appliance VLANS
    $ApplianceVLANS = $network | Get-MerakiNetworkApplianceVLANS
    if ($ApplianceVLANS) {
        foreach ($ApplianceVLAN in $ApplianceVLANS) {
            $vlan = New-Object VLAN
            $vlan.NetworkName = $Network.Name
            $vlan.VLAN = $ApplianceVLAN.Id
            $vlan.Name = $ApplianceVLAN.name
            $vlan.Subnet = $ApplianceVLAN.subnet

            $VLANS.Add($vlan)
        }
    }

    #Is there a stack
    $Stacks = $Network | Get-MerakiNetworkSwitchStacks
    if ($Stacks) {
        foreach ($Stack in $Stacks) {
            $Interfaces = Get-MerakiSwitchStackRoutingInterfaces -networkId $Network.Id -id $Stack.Id
            if ($interfaces) {
                foreach ($interface in $interfaces) {
                    $vlan = New-Object VLAN
                    $vlan.NetworkName = "-"
                    $vlan.VLAN = $interface.vlanId
                    $vlan.name = $interface.name
                    $vlan.Subnet = $interface.subnet

                    $VLANS.Add($vlan)
                }
            }
        }
    }
    #Switches
    $Switches = $Network |Get-MerakiNetworkDevices | Where-Object {$_.model -like "MS*"}
    foreach ($switch in $switches) {
        if ($Stacks) {
            foreach ($stack in $Stacks) {
                if ($Stack.serials -notcontains $switch.serial) {
                    $interfaces = $switch | Get-MerakiSwitchRoutingInterfaces
                    if ($interfaces) {
                        foreach ($interface in $interfaces) {
                            $vlan = New-Object VLAN
                            $vlan.NetworkName = "-"
                            $vlan.VLAN = $Interface.vlanId
                            $vlan.name = $interface.name
                            $vlan.Subnet = $interface.Subnet

                            $VLANS.Add($vlan)
                        }
                    }
                }
            }
        } else {
            $interfaces = Get-MerakiSwitchRoutingInterfaces -serial $switch.serial
            if ($interfaces) {
                foreach ($interface in $interfaces) {
                    $vlan = New-Object VLAN
                    $vlan.NetworkName = "-"
                    $vlan.VLAN = $Interface.vlanId
                    $vlan.name = $interface.name
                    $vlan.Subnet = $interface.Subnet

                    $VLANS.Add($vlan)
                }
            }  
        }
    }
}

$excel = $VLANS.ToArray() | Export-Excel -ExcelPackage $excel -WorksheetName $Worksheet `
                                            -StartRow $StartRow -StartColumn $StartColumn `
                                            -TableName "Networks" -Title "Networks" @titleParams `
                                        -AutoSize -Numberformat Text -PassThru

if ($IsWindows) {
    Close-ExcelPackage $excel -Show                        
} else {
    if ($IsLinux) {        
        Close-ExcelPackage $excel        
        $msg = "Open {0} in yur preferred spreadsheet application." -f $document
        Write-Host $msg
        Write-Host "LibreOffice calc will lose most of the formatting."
        Write-Host "WPS Office Spreadsheet will retain all the formatting"
    } else {
        #MacOS, I have no MAC to test on yet.
    }
}                                        
