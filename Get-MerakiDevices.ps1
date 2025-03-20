using namespace System.Collections.Generic

#Requires -Modules @{ModuleName="Meraki-API-V1"; ModuleVersion="0.0.3"}
#Requires -Modules @{ModuleName="Smartsheet"; ModuleVersion="1.0.0"}

# Create the list to hold the data
$DeviceList = [List[PsObject]]::New()

# Get All Meraki Networks
$Networks = Get-MerakiNetworks

foreach ($Network in $Networks) {
    # Get the devices for this network
    $Devices = $Network | Get-MerakiNetworkDevices | Sort-Object -Property Model -Descending
    write-host "Getting Devices for network $($Network.name)"
    foreach ($Device in $Devices) {
        if ($device) {
            $DeviceRecord = [PSCustomObject]@{
                Serial = $Device.Serial
                NetworkName = $Network.name
                DeviceName = $Device.name
                Model = $Device.model
                Mac = $Device.Mac
                Firmware = $Device.Firmware
            }
            $DeviceList.Add($DeviceRecord)
        }
    }
}

$DeviceList.ToArray() | Export-SmartSheet -SheetName "BBC Meraki Devices" 

