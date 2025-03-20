#Requires -Modules @{ModuleName = "ActiveDirectory"; ModuleVersion = "1.0.0.0"}
#Change DNS Server on Remote Servers
#
# Author: Cliff Williams
# Revised: 02/11/2020
# 
# Overview: Reports on current Status DNS setting on computers and optionally changes these settings.
#
# Parameters:
#	ComputerName: 
#		Required: Optional
#		Type: String
#		Precedent: Takes precedent over organizational Unit and InputFile
#		Reports of makes changes to a specific computer.
#
#	DNSServer1:
#		Required: Required if ComputerName is present.
#		Type: A string array
#		Precedent: None
#		Remarks: Primary DNS server IP address.
#
#	DNSServer2:
#		Required: Optional
#		Type: A string array
#		Precedent: None
#		Remarks: Secondary DNS server IP address.
#
#	OrganizationalUnit:
#		Required: Optional
#		Type: String
#		Precedent: Takes precedent over inputFile, Superseded by ComputerName, Required DNSServers parameter to make changes.
#		Remarks: The Organizational Unit to search for servers in.
#
#	InputFile:
#		Required: Optional
#		Type: String
#		Precedent: None
#		Remarks: A comma separated file containing data on the server to process. For format see parameter FileType.
#
#	ReportOnly
#		Required: Optional (default = false)
#		Type: switch
#		Restrictions: Valid valued are 'Computers' or 'OUs'
#		Remarks: Defines what format the input file will be in. 
#			Computers: A list of computer names with the word 'Computer' as a column header. 1 column only
#			OUs: Headers are OU, DNS1, DNS2. OU = list of Organizational Units, DNS1 is the primary DNS server IP for this OU and DNS2 is the 
#				 secondary DNS server for this OU.
#
#	InputFile Format:
#		The computer Input File format should be as follows:
#			ComputerName, [NewDNS1], [NewDNS2]
#		The OU input file format should ne as followsL
#			OrganizationalUnit, [NewDNS1], [NewDNS2]
#		The DNS entries are optional if you are only doing a report file.
#		If you create a report file from an input file you can re-use the output file file to update the DNS settings.
#		The report creates a file as:
#			Organizational Unit, ComputerName, OldDNS1, OldDNS1, NewDNS1, NewDNS2
#		Update the file by adding in the NewDNS1 and New DNS2 entries
#
#	OutputFile:
#		Required: Optional
#		Type: String
#		Remarks: File to write the Report out to in CSV format. You can specify the output file on any command combination and it will be
#				 created. If not provided the report is output to the console.
#
#	Dependencies:
#		Active Directory Module: Install-Module ActiveDirectory
#		Convert ADName Module: Install-Module ConvertADName
#
#	Examples:
#
#		Report on current DNS setting for a computer.
#		ChangeDNSServers.ps1 -ComputerName 'Server01' -ReportOnly -OutputFile DNSreport.csv
#
#		Change DNS setting for a single Computer.
#		ChangeDNSServers.ps1 -ComputerName 'Server01' -DNSServer1 '10.100.100.1' -DNSServer2 "10.100.100.2"
#
#		Report DNS settings on a single OU
#		ChangeDNSSettings.ps1 -OrganizationalUnit 'Acme.com/Western.Oregon' -OutputFile DNSReport.csv
#
#		Change DNS server of a single OU.
#		ChangeDNSServers.ps1 -OrganizationalUnit 'Acme.com/Western/Oregon' -DNSServer1 "10.100.101.1" -DNSServer2 "10.100.101.2"
#
#		Report DNS settings from a computer input file
#		ChangeDNSSettings.ps1 -inputFile computers.csv -OutputFile DNSReport.csv
#
#		Change DNS server using a Computer input File
#		ChangeDNSServers.ps1 -InputFile 'Computers.csv' -FileType 'Computers' -DNSServers "10.100.103.10","10.100.103.20"
#
#		Report DNS settings using am OU input file
#		ChangeDNSSettings.psq -InputFile OrganizationalUnits.csv -FileType 'OUs' -OutputFile DNSReport.csv
#
#		Change DNS servers using an OU input File
#		ChangeDNSServers.ps1 -inputFile 'OrganizationalUnits.csv' -FileType 'OUs'
#
Param (
	[string]$computerName,
	[string]$DNSServer1,
	[string]$DNSServer2,
	[string]$OrganizationalUnit,
	[string]$inputFile,
	[switch]$reportOnly,
	[ValidateSet('Computers','OUs')]
	[String]$FileType,
	[ValidateSet('Base',0,'OneLevel',2,'SubTree',3)]
	$SearchScope = 'OneLevel',
	[String]$OutputFile
)

$ErrorActionPreference = "STOP"

# Get-PSSnapin -Registered | Where-Object {$_.name -like "Quest*"} | Add-PSSnapin
# try {
# 	import-Module ActiveDirectory
# } Catch {}


Class Server
{
	[string]$OU
	[String]$ComputerName
	[string]$OldDNS1
	[string]$OldDNS2
	[String]$NewDNS1
	[String]$NewDNS2
}
$Report = New-Object System.Collections.Generic.List[Server]

Function ChangeDNSServer() {
	param ( 
		$Computer,
		[string]$DNS1,
		[string]$DNS2
	)

	"Checking computer $($computer.Name)"
	If (-not (Test-Connection -ComputerName $Computer.Name -Quiet)) { 
		"Server $($Computer.Name) not accessible"
		return 
	} 

	$Server = New-Object Server
	$Server.OU = $Computer.ParentContainer
	$Server.ComputerName = $Computer.Name

	try {
		$NICs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $computer.name | Where-Object { $_.IPEnabled -eq $true }
	} catch {
		write-host $_
		return
	}

	foreach ($NIC in $NICs) {
		$DNSSearchOrder = $NIC.DNSServerSearchOrder
		for ($i=0; $i -lt $DNSSearchOrder.length; $i++) {
			If ($i -eq 0) {
				$Server.OldDNS1 = $DNSSearchOrder[$i]
				if (-not $reportOnly) {
					$DNSSearchOrder[$i] = $DNS1		
					$Server.NewDNS1 = $DNS1		
				}
			} elseIf ($i -eq 1) {
				$Server.OldDNS2 = $DNSSearchOrder[$i]
				if (-not $reportOnly) {
					$DNSSearchOrder[$i] = $DNS2
					$Server.NewDNS2 = $DNS2
				}
			}
		}

		if (-not $reportOnly) {
			[void]$NIC.SetDNSServerSearchOrder($DNSSearchOrder)
			[void]$NIC.SetDynamicDNSRegistration("TRUE")
		}
	}
		
	$Report.Add($Server)
}
Function Get_ADComputersByOU($OU) {
	if (-not ($OU.contains("DC"))) {
		$OU = Convert-ADName -UserName $OU -OutputType "DN"		 
	}
	$Computers = Get-ADComputer -Filter {OperatingSystem -like "*Server*"} -SearchBase $OU -SearchScope	$SearchScope

	return $Computers
}

if ($computerName) {
	$computer = Get-ADComputer $computerName
	ChangeDNSServer $Computer $DNSServer1 $DNSServer2
} elseIf ($inputFile) {
	if ($FileType -eq 'Computers') {
		$Computers = Import-Csv $inputFile
		foreach ($Item in $Computers) {
			$computer = Get-ADComputer $item.ComputerName			
			ChangeDNSServer $computer $Item.NewDNS1 $Item.NewDNS2
		}
	} elseIf ($FileType -eq 'OUs') {
		$OUs = import-csv $inputFile
		foreach ($OU in $OUs) {
			$Computers = Get_ADComputersByOU $OU.OU
			foreach ($Computer in $Computers) {
				ChangeDNSServer $computer $OU.NewDNS1 $OU.NewDNS2
			}
		}
	} else {
		Write-Host "File Type parameter not set" -ForegroundColor Red
	}
} elseIF ($OrganizationalUnit) {
	$Computers = Get_ADComputersByOU $OU
	foreach ($computer in $Computers) {
		ChangeDNSServer $computer $DNSServers1 $DNSServers2
	}
}
$Report.ToArray()
if ($OutputFile) {
	$Report.ToArray() | Export-Csv $OutputFile -NoTypeInformation
}
