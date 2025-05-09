Param (
	[string]$parentContainer,
	[string]$SiteName,
	[string]$SavePath,
	[string]$ComputerName
)

#$ErrorActionPreference = "Stop"
Import-Module ActiveDirectory
Get-PSSnapin -Registered | Where-Object {$_.name -like "Quest*"} | Add-PSSnapin

Function Get-SiteForAddress($IPAddress)
{
	foreach ($Site in $ADSites)
	{
		foreach ($Subnet in $Site.Subnets)
		{
			$SubnetName=$Subnet.name
			$S1=$SubnetName.substring(0, $SubnetName.lastIndexOf("."))
			$S2=$IPAddress.substring(0, $IPAddress.LastIndexOf("."))
			If ($S1 -eq $S2)
			{
				return $Site.name
			}
		}
	}
	return $false
}

$xl = New-Object -ComObject "Excel.application"
$xl.Visible = $true
$WB=$xl.Workbooks.add()
$WS=$WB.ActiveSheet

$ServerList = @()
if (-not $SiteName) {
	[array]$ADSites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites | Sort-Object Name
}
else {
	[array]$ADSites
	$ADSites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites | ?{$_.name -eq $SiteName}
}

if ($ComputerName -ne '') {
	$servers = @()
	$Servers += Get-QADComputer $ComputerName
} else {

	if ($parentContainer -eq '') {
		$Servers = Get-QADComputer -SizeLimit 0 -OSName "*Server*"
	}
	else {
		$Servers = Get-QADComputer -OSName "*server*" -SearchRoot $parentContainer
	}
}
#Insert Main column  Headers
$WS.cells.item(1,3)="BBII Server Listing"

$WS.cells.item(2,1)="Site"
$WS.cells.item(2,2)="Server"
$WS.cells.item(2,3)="IP Address"
$ws.Cells.item(2,4)="Operating System"
$ws.Cells.item(2,5)="Parent Container"

$Row=3
"Gathering Server/Site Information"
foreach ($Server in $Servers)
{
	If (Ping-Host($Server.name))
	{
		$IP=Get-DnsEntry -iphost $Server.name
		$Site = get-SiteForAddress $IP
		If (!$Site) {
			$Site="Warning! No site found!"
		} Else {
			"Server: $($Server.name) is alive at $IP in site $Site"
			$svr = "" | Select-Object Site, Server, IP, ParentContainer
			$svr.Site = $Site
			$svr.Server = $Server.Name
			$svr.IP = $IP
			$svr.ParentContainer = $Server.ParentContainer
			$ServerList += $svr
		}
	}
}
$prevSite=$null

foreach ($svr in $ServerList | sort "Site")
{
	"Processing server $($Svr.server)"
	If ($prevSite -ne $svr.Site)
	{
		$WS.cells.item($Row,1)=$svr.Site
		$prevSite = $svr.Site
	}
	$WS.cells.item($Row,2)=$svr.server
	$WS.cells.item($Row,3)=$svr.IP
	$ws.Cells.item($Row,5)=$svr.ParentContainer
	try
	{
		$OS = gwmi -Class Win32_OperatingSystem -ComputerName $svr.server
	}
	Catch {
		"Server unavailable"
		Continue
	}
	$WS.cells.item($Row,4)=$OS.Caption
	$Row += 1
	$LDs=gwmi -Class Win32_LogicalDisk -ComputerName $Svr.server | where {$_.DriveType -eq '3'} -ErrorAction SilentlyContinue
	If ($LDS)
	{
		"$($LDS.Length) Logical Drives found."
		$WS.cells.item($Row,2)="Drive"
		$WS.cells.item($Row,3)="Size GB"
		$WS.cells.item($Row,4)="Used GB"
		$WS.cells.item($Row,5)="Free GB"

		$Row += 1
		$firstRow = $Row
		foreach ($LD in $LDs)
		{
			$WS.cells.item($Row,2) = $LD.DeviceID
			$WS.cells.item($Row,3) = "{0:N2}" -f ($LD.Size / 1GB)
			$Used = $LD.Size - $LD.Freespace
			$WS.cells.item($Row,4) = "{0:N2}" -f ($Used / 1GB)
			$WS.cells.item($Row,5) = "{0:N2}" -f ($LD.Freespace / 1GB)
			$Row += 1
		}
		$WS.Cells.Item($Row,3).formula = "=SUM({0}:{1})" -f $WS.Cells.item($firstRow,3).Address(), $WS.Cells.item($Row -1,3).address()
		$WS.Cells.Item($Row,4).formula = "=SUM({0}:{1})" -f $WS.Cells.item($firstRow,4).Address(), $WS.Cells.item($Row -1,4).address()
		$WS.Cells.Item($Row,5).formula = "=SUM({0}:{1})" -f $WS.Cells.item($firstRow,5).Address(), $WS.Cells.item($Row -1,5).address()
	#	$WS.Cells.Item($row,6).formula = "=SUM({0}:{1})" -f $WS.Cells.Item($Row,2).Address(), $WS.Cells.Item($Row,5).address()
		$Row += 1
		$Processors = Get-WmiObject -Class Win32_Processor -ComputerName $Svr.server
		$WS.cells.item($Row,2)="Processor"
		$WS.cells.item($Row,3)="Speed Khz"
		$WS.cells.item($Row,4)="Address Width"
		$WS.cells.item($Row,5)="Cores"
		$WS.Cells.item($Row,6)="Logical Processors"
		$Row += 1
		$ProcNum=1
		foreach ($proc in $Processors)
		{
			$WS.Cells.item($Row,2) = $ProcNum
			$WS.Cells.item($Row,3) = $proc.maxclockspeed
			$WS.cells.item($Row,4) = $proc.addressWidth
			$WS.cells.item($Row,5) = $proc.numberOfCores
			$WS.cells.item($Row,6) = $proc.NumberOfLogicalProcessors
			$ProcNum += 1
			$Row += 1
		}
		$RAM = (gwmi -Class Win32_ComputerSystem -ComputerName $svr.server).TotalPhysicalMemory
		$WS.cells.item($Row,2) = "Memory (GB):"
		$WS.cells.item($Row,3) = "{0:N2}" -f ($RAM / 1GB)

		$Row += 2
	}
	Else
	{
		Write-Host "Unable to query server $($svr.server)."
	}

}
if ($SavePath) {
	$WB.saveAs($SavePath + "\BBIIServers.xlsx")
	$WB.close()
	$xl.quit()
}
