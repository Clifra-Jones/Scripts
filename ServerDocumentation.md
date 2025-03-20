![Balfour Logo](https://www.balfourbeattyus.com/Balfour-dev.allata.com/media/content-media/2017-Balfour-Beatty-Logo-Blue.svg?ext=.svg)

# Server Documentation Script

This script produces an Excel workbook that documents important items about a server including Logical Disks, Processors, Network Adapters, Local Groups, and installed software and updates.

## Required Modules

This script required the following modules:

- **Active Directory**
- **ImportExcel**
- **ConvertADName**

## Parameters

The script can be run using the following parameters:

- **Domain**: The Domain to retrieve server objects from.
- **ParentContainer**: The Active Directory Organizational Unit to pull server objects from. This can be provided in LDAP or Canonical format.
- **SiteName**: The Active Directory Site to pull server objects from.
- **ComputerName**: Run the report on a single computer
- **OutputPath**: Folder to place the output file in. The default is the script folder.
- **Credentials**: A PSCredentials object containing credential with access to the servers.
- **UseIntegrated**: Use the current logged on user account to access the servers.
- **LogFailed**: Log all failed access attempts

The resulting Excel workbook will have a worksheet for each server documented.

This script uses the Common Information Model (CIM) functions in PowerShell to query information from the servers. CIM is only supported in Windows Server 2012 and later. The script will fall back to WMI for Windows Server 2008.

The script also attempts to connect to the server using SSL for CIM communications. If that fails the script will fall back to HTTP protocol.

## Script source

```powershell
#Requires -Modules @{ModuleName="ActiveDirectory"; ModuleVersion="1.0.0.0"}
#Requires -Modules @{ModuleName="ImportExcel"; ModuleVersion="7.8.1"}
#Requires -Modules @{ModuleName="ConvertADName"; ModuleVersion="1.0.0.0"}

Param (
    [string]$Domain,
    [string]$parentContainer,
    [string]$SiteName,
    [string]$OutputPath, 
    [string]$ComputerName,
    [pscredential]$Credentials,
    [switch]$UseIntegrated,
    [string[]]$ExcludeList,
    [switch]$LogFailed
)

$ErrorActionPreference = "Stop"
if (-not $Credentials) {
    if (-not $UseIntegrated) {
        $Credentials = Get-Credential
    }
}

#Import-Module ActiveDirectory -WarningAction SilentlyContinue
#Import-Module ImportExcel
#Import-Module 'd:\Users\cwilliams\OneDrive - Balfour Beatty\Scripts\MOA_Module\MOA_Module.psd1'
[reflection.assembly]::LoadWithPartialName("System.DirectoryServices")

$ADParams = @{}

if ($Domain) {
    $ADParams.Add("Server", $domain)
}


if (-not $OutputPath) {
    $OutputPath = $PSScriptRoot
}

if ($LogFailed) {
    $script:Failures  = [System.Collections.Generic.list[psobject]]::New()
    Class Failure {
        [string]$ComputerName
        [String]$Protocol
        [string]$ErrorRecord

        Failure (
            [string]$_ComputerName,
            [string]$_Protocol,
            [string]$_errorRecord
        ){
            $this.ComputerName = $_ComputerName
            $this.protocol = $_Protocol
            $this.ErrorRecord = $_errorRecord.ToString()
        }
    }
}

function Get-IpRange {
    <#
    .SYNOPSIS
        Given a subnet in CIDR format, get all of the valid IP addresses in that range.
    .DESCRIPTION
        Given a subnet in CIDR format, get all of the valid IP addresses in that range.
    .PARAMETER Subnets
        The subnet written in CIDR format 'a.b.c.d/#' and an example would be '192.168.1.24/27'. Can be a single value, an
        array of values, or values can be taken from the pipeline.
    .EXAMPLE
        Get-IpRange -Subnets '192.168.1.24/30'
        
        192.168.1.25
        192.168.1.26
    .EXAMPLE
        (Get-IpRange -Subnets '10.100.10.0/24').count
        
        254
    .EXAMPLE
        '192.168.1.128/30' | Get-IpRange
        
        192.168.1.129
        192.168.1.130
    .NOTES
        Inspired by https://gallery.technet.microsoft.com/PowerShell-Subnet-db45ec74
        
        * Added comment help
    #>
    
    [CmdletBinding(ConfirmImpact = 'None')]
    Param(
        [Parameter(Mandatory, HelpMessage = 'Please enter a subnet in the form a.b.c.d/#', ValueFromPipeline, Position = 0)]
        [string[]] $Subnets
    )

    begin {
        Write-Verbose -Message "Starting [$($MyInvocation.Mycommand)]"
    }

    process {
        foreach ($subnet in $subnets) {
            if ($subnet -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}/\d{1,2}$') {
                #Split IP and subnet
                $IP = ($Subnet -split '\/')[0]
                [int] $SubnetBits = ($Subnet -split '\/')[1]
                if ($SubnetBits -lt 7 -or $SubnetBits -gt 30) {
                    Write-Error -Message 'The number following the / must be between 7 and 30'
                    break
                }
                #Convert IP into binary
                #Split IP into different octects and for each one, figure out the binary with leading zeros and add to the total
                $Octets = $IP -split '\.'
                $IPInBinary = @()
                foreach ($Octet in $Octets) {
                    #convert to binary
                    $OctetInBinary = [convert]::ToString($Octet, 2)
                    #get length of binary string add leading zeros to make octet
                    $OctetInBinary = ('0' * (8 - ($OctetInBinary).Length) + $OctetInBinary)
                    $IPInBinary = $IPInBinary + $OctetInBinary
                }
                $IPInBinary = $IPInBinary -join ''
                #Get network ID by subtracting subnet mask
                $HostBits = 32 - $SubnetBits
                $NetworkIDInBinary = $IPInBinary.Substring(0, $SubnetBits)
                #Get host ID and get the first host ID by converting all 1s into 0s
                $HostIDInBinary = $IPInBinary.Substring($SubnetBits, $HostBits)
                $HostIDInBinary = $HostIDInBinary -replace '1', '0'
                #Work out all the host IDs in that subnet by cycling through $i from 1 up to max $HostIDInBinary (i.e. 1s stringed up to $HostBits)
                #Work out max $HostIDInBinary
                $imax = [convert]::ToInt32(('1' * $HostBits), 2) - 1
                $IPs = @()
                #Next ID is first network ID converted to decimal plus $i then converted to binary
                For ($i = 1 ; $i -le $imax ; $i++) {
                    #Convert to decimal and add $i
                    $NextHostIDInDecimal = ([convert]::ToInt32($HostIDInBinary, 2) + $i)
                    #Convert back to binary
                    $NextHostIDInBinary = [convert]::ToString($NextHostIDInDecimal, 2)
                    #Add leading zeros
                    #Number of zeros to add
                    $NoOfZerosToAdd = $HostIDInBinary.Length - $NextHostIDInBinary.Length
                    $NextHostIDInBinary = ('0' * $NoOfZerosToAdd) + $NextHostIDInBinary
                    #Work out next IP
                    #Add networkID to hostID
                    $NextIPInBinary = $NetworkIDInBinary + $NextHostIDInBinary
                    #Split into octets and separate by . then join
                    $IP = @()
                    For ($x = 1 ; $x -le 4 ; $x++) {
                        #Work out start character position
                        $StartCharNumber = ($x - 1) * 8
                        #Get octet in binary
                        $IPOctetInBinary = $NextIPInBinary.Substring($StartCharNumber, 8)
                        #Convert octet into decimal
                        $IPOctetInDecimal = [convert]::ToInt32($IPOctetInBinary, 2)
                        #Add octet to IP
                        $IP += $IPOctetInDecimal
                    }
                    #Separate by .
                    $IP = $IP -join '.'
                    $IPs += $IP
                }
                Write-Output -InputObject $IPs
            } else {
                Write-Error -Message "Subnet [$subnet] is not in a valid format"
            }
        }
    }

    end {
       # Write-Verbose -Message "Ending [$($MyInvocation.Mycommand)]"
    }
}

Function LogIt() {
    Param (
        [string]$ComputerName,
        [string]$Protocol,
        [string]$ErrorRecord
    )
    [Failure]$Failure = [failure]::New($ComputerName, $Protocol, $ErrorRecord)
    
    $Failures.Add($Failure)
}

function Format-InstallDate() {
    Param(
        [string]$installDate
    )

    $strDate = "{0}/{1}/{2}" -f $_.InstallDate.SubString(0,4), $_.InstallDate.Substring(4,2), $_.InstallDate.SubString(6,2)

    return $strDate
}

$workbookName = "{0}/Servers.xlsx" -f $OutputPath

<# 
 .Synopsis 
 Validates an ipaddress is in a given subnet based on CIDR notation 
.DESCRIPTION 
Clone of the c# code given in http://social.msdn.microsoft.com/Forums/en-US/29313991-8b16-4c53-8b5d-d625c3a861e1/ip-address-validation-using-cidr?forum=netfxnetcom 
.EXAMPLE 
IS-InSubnet -ipaddress 10.20.20.0 -Cidr 10.20.20.0/16 
 .Author 
Srinivasa Rao Tumarada 
#> 
 
Function Test-InSubnet() 
{ 
 
[CmdletBinding()] 
[OutputType([bool])] 
Param( 
    [Parameter(
        Mandatory=$true, 
        ValueFromPipelineByPropertyName=$true, 
        Position=0)] 
        [validatescript(
            {
                ([System.Net.IPAddress]$_).AddressFamily -match 'InterNetwork'
            }
        )] 
        [string]$ipaddress, 
        [Parameter(
            Mandatory=$true, 
            ValueFromPipelineByPropertyName=$true, 
            Position=1
        )] 
        [validatescript(
            {
                (([system.net.ipaddress]($_ -split '/'|Select-Object -first 1)).AddressFamily -match 'InterNetwork') -and (0..32 -contains ([int]($_ -split '/'|Select-Object -last 1) )) 
            }
        )] 
        [string]$Cidr
    ) 
    Begin{ 
        $Addresses = Get-IpRange -Subnets $Cidr
    } 
    Process{ 
        If ($ipaddress -in $Addresses) {
            return $true
        } else {
            return $false
        }
    } 
    end { Write-output $status } 
} 

function Get-SiteForAddress() {
    Param (
        [string]$IpAddress,
        [psobject[]]$Sites
    )

    foreach ($Site in $ADsites) {
        foreach ($subnet in $Site.Subnets) {
            $SubnetName = $Subnet.Name  
            If (Test-InSubnet -ipaddress $IpAddress -Cidr $SubnetName) {
                return $Site.Name
            }
        }         
    }
    return $false
}

function Get-ADParentContainer() {
    Param (
        [string]$DN
    )
    $DE = New-Object System.DirectoryServices.DirectoryEntry("LDAP://{0}" -f $DN)
    if ($DE) {
        return $DE.Parent
    } 
    return $false
}


function Get-AccessRights() {
    Param (
        [UInt32]$AccessMask
    )
    $simplePermissions = [ordered]@{
        [uint32]'0x1f01ff' = 'FullControl'
        [uint32]'0x0301bf' = 'Modify'
        [uint32]'0x0200a9' = 'ReadAndExecute'
        [uint32]'0x02019f' = 'ReadAndWrite'
        [uint32]'0x020089' = 'Read'
        [uint32]'0x000116' = 'Write'
    }

    $permissions = @()

    $permissions += $simplePermissions.Keys | ForEach-Object {
        if (($AccessMask -band $_) -eq $_) {
            $simplePermissions[$_]
            $AccessMask = $AccessMask -band (-bnot $_)
        }
    }

    return $permissions
}

#$ServerList = New-Object System.Collections.Generic.List[psObject]


if (-not $SiteName) {
    [array]$ADSites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites | Sort-Object Name
} else {
    [array]$ADsites = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest().Sites | Select-Object {$_.Name -eq $SiteName}
}

if ($ComputerName) {
    $Servers = @()
    $Servers += Get-ADComputer $ComputerName -Properties * @ADParams
} elseif (-not $Servers) {
    if (-not $parentContainer) {
        $Servers = Get-ADComputer -Filter {OperatingSystem -like "*Server*"} -ResultSetSize Unlimited -Properties * @ADParams
    } else {
        if (-not $parentContainer.StartsWith("OU=")) {
            $Parentcontainer = Convert-ADName -UserName $parentContainer -OutputType DN
        }
        $Servers = Get-ADComputer -Filter {OperatingSystem -like "*Server*"} -SearchBase $parentContainer @ADParams
    }
}

if (Test-Path -Path $workbookName) {
    Remove-Item $workbookName -Force
}

$titleParams = @{
    TitleBold=$true;
    TitleSize=12;
}

$tableParams = @{
    BorderColor="black";
    BorderRight="thin";
    BorderLeft="thin";
    BorderTop="thin";
    BorderBottom="thin";
    FontSize=9
}

function documentServer ($svr, $excel) {   
    [void](Add-Worksheet -ExcelPackage $excel -WorksheetName $svr.Server)
    if ($excel.WorkBook.Worksheets['Sheet1']) {
        $excel.WorkBook.Worksheets.Delete('Sheet1')
    }

    $StartRow = 1
    $StartColumn = 1

    Write-Host ": Server Properties" -ForegroundColor Yellow
    $TableName = "{0}Properties" -f $svr.Server
    $serverProps = $Svr.PSobject.Properties | Select-Object Name, Value | Where-Object {$_.Name -ne "CimSessionOptions"}
    $excel = $ServerProps | Select-Object @{Name="Property";Expression={$_.Name}}, Value | `
        Export-Excel -ExcelPackage $excel `
            -WorksheetName $svr.Server `
            -StartRow $StartRow `
            -StartColumn $StartColumn `
            -TableName $TableName `
            -Title "Server" `
            @titleParams `
            -AutoSize `
            -NumberFormat Text `
            -PassThru

    $StartRow += $ServerProps.Count + 3

    #Computer System
    Write-Host ": Computer System" -ForegroundColor Yellow
    $CS = Get-CimInstance -CimSession $CimSession -ClassName Win32_ComputerSystem | Select-Object Domain, Manufacturer, Model, Name, PrimaryOwnerName, TotalPhysicalMemory
    $csProps = $CS.PSObject.Properties | Select-Object @{Name="Property"; Expression={$_.Name}}, Value
    $excel = $CSProps | Export-Excel    -ExcelPackage $excel `
                                        -WorksheetName $svr.Server `
                                        -StartRow $StartRow `
                                        -StartColumn $StartColumn `
                                        -TableName "$($Svr.Server)ComputerSystem" `
                                        -Title "Computer System" `
                                        @titleParams `
                                        -NumberFormat Text `
                                        -AutoSize `
                                        -PassThru

    $StartRow += $csProps.Count + 3                                        

    #Disks
    Write-Host ": Logical Disks" -ForegroundColor Yellow
    #$CimSessionOptions = $Svr.CimSessionOptions
    #$CimSession = New-CimSession -SessionOption $CimSessionOPtions -ComputerName $svr.Server
    $LDs = Get-CimInstance -CimSession $CimSession -ClassName Win32_LogicalDisk |Where-Object {$_.DriveType -eq '3'} -ErrorAction SilentlyContinue
    If ($LDs) {
        ": {0} Logical Drives found." -f $LDs.Count
        $excel = $LDs | Select-Object   @{Name="Device ID";Expression={$_.DeviceID}}, `
                                        @{Name="Size GB";Expression={"{0:N2}" -f ($_.Size / 1GB)}}, `
                                        @{Name="Used GB";Expression={"{0:N2}" -f (($_.Size - $_.Freespace) / 1GB)}}, `
                                        @{Name="Freespace GB";Expression={"{0:N2}" -f ($_.Freespace / 1GB)}} | `
                Export-Excel    -ExcelPackage $excel `
                                -WorksheetName $Svr.Server `
                                -StartRow $StartRow `
                                -StartColumn $StartColumn `
                                -TableName "$($svr.Server)LDSs" `
                                -Title "LogicalDisks" `
                                @titleParams `
                                -AutoSize `
                                -NumberFormat Text `
                                -PassThru
        
        $StartRow += $LDs.Count + 3
    }

    Write-Host ": Processors" -ForegroundColor Yellow
    $Processors = Get-CimInstance -CimSession $CimSession -ClassName Win32_Processor

    $excel = $Processors | Select-Object    @{Name="Speed Khz";Expression={$_.MaxClockSpeed}}, `
                                            @{Name="Address Width";Expression={$_.addressWidth}}, `
                                            @{Name="Number of Cores";Expression={$_.numberOfCores}}, `
                                            @{Name="Logical Processors";Expression={$_.numberOfLogicalProcessors}} | `
                            Export-Excel    -ExcelPackage $excel `
                                            -WorksheetName $svr.Server `
                                            -StartRow $StartRow `
                                            -StartColumn $StartColumn `
                                            -TableName "$($svr.Server)Processors" `
                                            -Title "Processors" `
                                            @titleParams `
                                            -AutoSize `
                                            -NumberFormat Text `
                                            -PassThru    
    $StartRow += $Processors.count + 3

    Write-Host ": Network Adapters" -ForegroundColor Yellow
    $NetworkAdapters = Get-CimInstance -CimSession $CimSession -ClassName Win32_NetworkAdapterConfiguration | Where-Object {$_.IPEnabled -eq $true}
    $excel = $NetWorkAdapters | Select-Object    Description,
                                        @{Name="MAC Address";Expression={$_.MACAddress}}, `
                                        @{Name="IP Address";Expression={$_.IPAddress -join ", "}}, `
                                        @{Name="Subnet";Expression={$_.IPSubnet -join ", "}}, `
                                        @{Name="IP Gateway";Expression={$_.DefaultIPGateway}}, `
                                        @{Name="DHCP Enabled";Expression={$_.DHCPEnabled}}, `
                                        @{Name="DHCP Lease Obtained";Expression={$_.DHCPLeaseObtained}}, `
                                        @{Name="DHCP Lease Expires";Expression={$_.DHCPLeaseExpires}}, `
                                        @{Name="DNS Host Name";Expression={$_.DNSHostName}}, `
                                        @{Name="DNS Server Search Order";Expression={$_.DNSServerSearchOrder -join ", "}}, `
                                        @{Name="DNS Domain";Expression={$_.DNSDomain}} | `
                        Export-Excel    -ExcelPackage $excel `
                                        -WorksheetName $svr.Server `
                                        -StartRow $StartRow `
                                        -StartColumn $StartColumn `
                                        -TableName "$($Svr.server)NICs" `
                                        -Title "Network Adapters" `
                                        @titleParams `
                                        -Numberformat Text `
                                        -AutoSize `
                                        -PassThru
    $StartRow += $NetworkAdapters.Count + 3

    Write-Host ": Local Group Membership" -ForegroundColor Yellow
    Set-ExcelRange -Range $excel.Workbook.Worksheets[$svr.Server].Cells[$StartRow, $StartColumn] -FontSize 14 -Bold -Value "Local Groups"    
    $StartRow += 1

    $Groups = Get-CimInstance -ClassName Win32_Group -CimSession $CimSession | Select-Object SID, Name
    foreach ($Group in $Groups) {
        $members = (Get-CimInstance -ClassName Win32_GroupUser -CimSession $CimSession).Where({$_.GroupComponent.Name -eq $Group.Name}).PartComponent | Select-Object Domain, Name
        if ($members) {
            $excel = $members | Export-Excel -ExcelPackage $excel `
                                    -WorksheetName $svr.Server `
                                    -StartRow $StartRow `
                                    -StartColumn $StartColumn `
                                    -TableName "$($svr.Server)$($group.name)" `
                                    -Title "$($group.name)" `
                                    @titleParams `
                                    -AutoSize `
                                    -Numberformat Text `
                                    -PassThru
            $StartRow += $members.count + 3
        }
    }

    #$StartRow += 2

    Write-Host ": Shares" -ForegroundColor Yellow
    $Shares = Get-CimInstance -CimSession $CimSession -ClassName Win32_Share
    $excel = $Shares | Select-Object Name, Description, Path | Export-Excel   -ExcelPackage $excel `
                            -WorksheetName $svr.Server `
                            -StartRow $StartRow `
                            -StartColumn $StartColumn `
                            -TableName "$($svr.server)Shares" `
                            -Title "Shares" `
                            @titleParams `
                            -AutoSize `
                            -NumberFormat Text `
                            -PassThru
    $StartRow += $Shares.count + 3      
    
    Write-Host ": Share Permissions" -ForegroundColor Yellow
    $SharePermissions = [System.Collections.Generic.List[psobject]]::New()
    Class Permission {
        [string]$Name
        [string]$Trustee
        [string]$Permission
    }
    $ShareSecSettings = Get-CimInstance -ClassName Win32_LogicalShareSecuritySetting -CimSession $CimSession

    foreach($share in $Shares) {
        $ShareSecSetting = $ShareSecSettings.Where({$_.Name -eq $share.name})
        $SecurityDescriptor = $ShareSecSetting | Invoke-CimMethod -MethodName GetSecurityDescriptor
        $Descriptor = $SecurityDescriptor.Descriptor
        $DACL = $Descriptor.DACL
        foreach ($ACL in $DACL) {
            $Perm = New-Object Permission
            $Perm.Name = $Share.Name
            $Perm.Trustee = $Acl.Trustee.Name
            $rights = Get-AccessRights $Acl.AccessMask
            $Perm.Permission = $Rights
            $SharePermissions.Add($Perm)
        }
    }
    if ($SharePermissions.Count -gt 0) {
        $excel = $SharePermissions.ToArray() | Export-Excel   -ExcelPackage $excel `
                                        -WorksheetName $svr.Server `
                                        -StartRow $StartRow `
                                        -StartColumn $StartColumn `
                                        -TableName "$($svr.server)SharesPerms" `
                                        -Title "Share Permissions" `
                                        @titleParams `
                                        -AutoSize `
                                        -NumberFormat Text `
                                        -PassThru
        $StartRow += $SharePermissions.Count + 3
   }

    Write-Host ": Installed Software (x64)" -ForegroundColor Yellow
    $PSOpts = New-PSSessionOption -SkipCACheck
    try {
        #try using SSL
        if ($Credentials) {
            $PSSession = New-PSSession -ComputerName $svr.Server -SessionOption $PSOpts -Port 5986 -UseSSL -Credential $Credentials
        } else {
            $PSSession = New-PSSession -ComputerName $svr.Server -SessionOption $PSOpts -Port 5986 -UseSSL            
        } 
    } catch {
            #try without SSL
            If ($LogFailed) {
                LogIt -ComputerName $Server.Name -Protocol "PSSession:HTTPS" -errorObject $_
            }
        try {
            if ($Credentials) {
                $PSSession = New-PSSession -ComputerName $svr.Server -SessionOption $PSOpts -Credential $Credentials
            } else {
                $PSSession = New-PSSession -ComputerName $svr.Server -SessionOption $PSOpts 
            }            
        } catch {
            Write-Host "Could not establish a PS Session" -ForgroundColor Yellow
            if ($LogFailed) {
                LogIt -ComputerName $server.Name -Protocol "PSSession:HTTP" -ErrorRecord $_
            }
            Write-Host $_
        }
    }
    If ($PSSession) {
        $scriptBlock = {Get-ItemProperty "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*" | Where-Object {$_.KBNumber -eq $null -and $_.DisplayVersion -ne $Null}}
        $Software = Invoke-Command -Session $PSSession -ScriptBlock $scriptBlock
        $excel = $Software | Select-Object  @{Name="Display Name";Expression={$_.DisplayName}}, `
                                            @{Name="Version";Expression={$_.DisplayVersion}}, `
                                            Publisher, `
                                            @{Name="Install Date";Expression={Format-InstallDate $_.InstallDate}} |
                            Export-Excel    -ExcelPackage $excel `
                                            -WorksheetName $svr.Server `
                                            -StartRow $StartRow `
                                            -StartColumn $StartColumn `
                                            -TableName "$($svr.Server)Software64" `
                                            -Title "Software (x64)" `
                                            @titleParams `
                                            -AutoSize `
                                            -Numberformat Text `
                                            -PassThru

        $StartRow += $Software.Count + 3

        Write-Host ": Installed Software (x32)" -ForegroundColor Yellow
        $scriptBlock = {Get-ItemProperty "HKLM:\Software\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" |Where-Object {$_.KBNumber -eq $null -and $_.DisplayVersion -ne $null}}
        $Software = Invoke-Command -Session $PSSession -ScriptBlock $scriptBlock
        $excel = $Software | Select-Object  @{Name="Display Name";Expression={$_.DisplayName}}, `
                                            @{Name="Version";Expression={$_.DisplayVersion}}, `
                                            Publisher, `
                                            @{Name="Install Date";Expression={Format-InstallDate $_.InstallDate}} |
                            Export-Excel    -ExcelPackage $excel `
                                            -WorksheetName $svr.Server `
                                            -StartRow $StartRow `
                                            -StartColumn $StartColumn `
                                            -TableName "$($svr.Server)Software32" `
                                            -Title "Software (x32)" `
                                            @titleParams `
                                            -AutoSize `
                                            -Numberformat Text `
                                            -PassThru

        $StartRow += $sOFTWARE.cOUNT + 3

        Write-Host ": Fixes" -ForegroundColor Yellow
        $scriptBlock = {Get-HotFix}
        $Fixes = Invoke-Command -Session $PSSession -ScriptBlock $scriptBlock
        $excel = $Fixes | Select-Object HotFixID, Description, `
                                        @{Name="Installed On";Expression={$_.InstalledOn}} | `
                        Export-Excel    -ExcelPackage $excel `
                                        -WorksheetName $svr.Server `
                                        -StartRow $StartRow `
                                        -StartColumn $StartColumn `
                                        -TableName "$($svr.Server)Fixes64" `
                                        -Title "Fixes (x64)" `
                                        @titleParams `
                                        -AutoSize `
                                        -Numberformat Text `
                                        -PassThru

        $StartRow += $Fixes.count + 3
    
    }
    
    $excel.Workbook.Worksheets[$svr.server].Tables | Foreach-Object {
        $_.Address | Set-ExcelRange @tableParams
    }    
}

$excel = Export-Excel -Path $workbookName -PassThru


foreach ($server in $servers) {
    if ($Server.Name -in $ExcludeList) {
        Continue
    }
    Write-Host "Documenting $($Server.Name)" -ForegroundColor Yellow
    if (Test-Connection $Server.Name -Count 2 -Quiet) {
        [string]$IP = (Resolve-DnsName -Name $Server.Name).IPAddress
        $IP = $IP.trim()
        $Site = Get-SiteForAddress $IP
        if (-not $Site) {
            $Site = "Warning! No site found!"
        }
        Write-Host  (": Server - {0} is alive at {1} in site {2}" -f $server.Name, $IP, $Site) -ForegroundColor Yellow
        #Test CIM connections and find the proper session options.    
        Write-Host "Connecting CIM Session"  -ForegroundColor Yellow
        if ($Server.OperatingSystem -Like "*2003*" -or $Server.OperatingSystem -Like "*2008*") {
            try {
                 #See if WinRM over HTTPS has been enabled.
                 $CimSessionOptions = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -UseSSL
                 If ($Credentials) {
                     $CimSession = New-CimSession -ComputerName $Server.Name -SessionOption $CimSessionOptions -Credential $Credentials
                 } else {
                     $CimSession = New-CimSession -ComputerName $Server.Name -SessionOption $CimSessionOptions
                 }
                
            } catch {
                if ($LogFailed) {
                    LogIt -ComputerName $Server.Name -Protocol "HTTPS" -ErrorObject $_
                }
                try {
                    #SSL Failed, see if the server will connect via DCom
                    $CimSessionOptions = New-CimSessionOption -Protocol DCom
                    if ($Credentials) {
                        $CimSession = New-CimSession -ComputerName $Server.Name -SessionOption $CimSessionOptions -Credential $Credentials
                    } else {
                        $CimSession = New-CimSession -ComputerName $Server.Name -SessionOption $CimSessionOptions
                    }   
                } catch {
                    if ($LogFailed) {
                        LogIt -ComputerName $Server.Name -Protocol "Dcom" -ErrorRecord $_
                    }
                    $msg =  "Server {0} is not accessible excluding!" -f $Server.Name
                    Write-Host $msg -forgroundColor Yellow
                }
            }
        } else {
            #Server version 2012 +
            try {
                # try to connect over HTTPS
                $CimSessionOptions = New-CimSessionOption -SkipCACheck -SkipCNCheck -skipRevocationCheck -UseSSL 
                if ($Credentials) {
                    $CimSession = New-CimSession -SessionOption $CimSessionOptions -ComputerName $Server.Name -Credential $Credentials
                } else {
                    $CimSession = New-CimSession -SessionOption $CimSessionOptions -ComputerName $Server.Name
                }
                
            } catch {        
                if ($LogFailed) {
                    LogIt -ComputerName $server.Name -Protocol "HTTPS" -ErrorRecord $_                
                }
                try {        
                    #HTTPS failed, try to connect using default setting
                    $CimSessionOptions = New-CimSessionOption -Protocol Default
                    if ($Credentials) {
                        $CimSession = New-CimSession -SessionOption $CimSessionOptions -ComputerName $Server.Name -Credential $Credentials
                    } else {
                        $CimSession = New-CimSession -SessionOption $CimSessionOptions -ComputerName $Server.Name
                    }
                    
                } catch {
                    if ($LogFailed) {
                        LogIt -ComputerName $Server.Name -Protocol "HTTP" -ErrorRecord $_
                    }
                    $msg =  "Server {0} is failed WinRM connection excluding!" -f $Server.Name
                    Write-Host $msg -ForgroundColor Yellow
                    Write-Host $_
                }
            } 
        }

        if ($CimSession) {
            # Before we begin make absolutely sure we can query the server ising CIM.
            try {
                [void](Get-CimInstance -CimSession $CimSession -ClassName Win32_ComputerSystem)
             } catch {
                Write-Host ($_.Exception.Message) -ForegroundColor Red
                Continue
             }

            $svr = [PSCUstomObject]@{
                Site = $Site
                Server = $Server.Name
                IP = $IP
                ParentContainer = Get-ADParentContainer $Server.DistinguishedName
                OperatingSystem = $Server.OperatingSystem
                CimSessionOptions = $CimSessionOptions
            }
            documentServer $svr $excel
        } else {
            $msg =  "Server {0} is not accessible excluding!" -f $Server.Name
            Write-Host $msg -ForgroundColor Yellow
        }

    } else {
        $msg = "Server {0} is not alive on the network" -f $server.name
        Write-Host $msg -ForgroundColor Yellow
    }
}
if ($LogFailed) {
    $StartRow = 1
    $StartColumn = 1
    If  ($Failures) {
        $excel = $Failures.toArray() | Export-Excel -ExcelPackage $excel `
                                                -WorksheetName "Failures" `
                                                -StartRow $StartRow `
                                                -StartColumn $StartColumn `
                                                -TableName "Failures" `
                                                -Title "Failures" `
                                                @titleParams `
                                                -AutoSize `
                                                -PassThru
    }
}

If ($excel) {
    Write-Host "Completed" -ForegroundColor Yellow
    Write-Host "Closing Excel Package" -ForgroundColor Yellow
    if ($IsWindows) {
        Write-Host "Opening Workbook" -ForgroundColor Yellow
        Close-ExcelPackage $excel -Show
    } Else {
        Write-Host "Saving WorkBook. Open in your preferred Spreadsheet application (Note: Libre Calc will lose most formatting)" -ForgroundColor Yellow
        Close-ExcelPackage $excel
    }
}
```
