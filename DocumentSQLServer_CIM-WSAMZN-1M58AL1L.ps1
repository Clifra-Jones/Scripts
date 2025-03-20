#Requires -Modules @{ModuleName="SqlServer"; ModuleVersion="21.1.18256"}
#Requires -Modules @{ModuleName="ImportExcel"; ModuleVersion="7.4.1" }

[CmdLetBinding()]
Param (
    [Parameter(
        Mandatory = $true,
        ValueFromPipelineByPropertyName = $true
    )]
    [Alias('ComputerName','Name')]
    [string]$DNSHostName,
    [string]$outputFolder
)

Begin {
    $ErrorActionPreference = 'Stop'
    $WarningPreference = 'SilentlyContinue'

#    Import-Module sqlserver
#    Import-Module ImportExcel

    if (-not $outputFolder) {
        $outputFolder = (get-location).path
    }

    $fileName = "{0}/SQLDocs.xlsx" -f (Get-item -Path $outputFolder).FullName

    if (Test-Path $filename) {
        Remove-Item $fileName
    }


    
    $CIMSessionOptions = New-CimSessionOption -SkipCACheck -SkipCNCheck -SkipRevocationCheck -UseSsl

    $excel = Export-Excel -Path $Filename -PassThru    
}

Process {
    if (Test-Connection $DNSHostName -Quiet -Count 2) {
        $Hostname = $DNSHostName.Split(".")[0]        
        [void](Add-Worksheet -ExcelPackage $excel -WorksheetName $HostName )
        if ($excel.Workbook.Worksheets["Sheet1"]) {
            $excel.Workbook.Worksheets.Delete("Sheet1")
        }

        $StartRow =1
        $StartColumn = 1

        $titleParams = @{
            TitleBold=$true
            TitleSize=12
        }

        $TableParams = @{
            BorderColor="black"
            BorderRight="thin"
            BorderLeft="thin"
            BorderTop="thin"
            BorderBottom="thin"
            FontSize=9
        }

        "Documenting: $HostName"

        #Establish CIM Session
        Write-Host "Establish CIM Session" -ForegroundColor Yellow
        try {
            $CIMSession = new-CIMSession -ComputerName $DNSHostName -SessionOption $CIMSessionOptions 
        } catch {
            Throw $_
        }
        
        #Verify CIM Connection
        try {
            $OS = Get-CimInstance -CimSession $CIMSession -ClassName Win32_OperatingSystem            
        } catch {
            "Server is unavailable via CIM. Please insure CIM is configured for SSL access."            
            return
        }       

        #Verify the connection to the SQL server 
        Write-Host "Verify SQL Connection" -ForegroundColor Yellow
        try {
            $instance=Get-SqlInstance -ServerInstance $DNSHostName
        } catch {
            "Cannot connect to SQL instance. Insure the account this script is running under is a sysadmin"
            return
        }
        
        ": Computer System"
        $ComputerSystem = Get-CimInstance -CimSession $CIMSession -ClassName Win32_ComputerSystem | `
            Select-Object Domain, Manufacturer, Model, @{Name="Owner";Expression={$_.PrimaryOwnerName}}, `
                @{Name="Memory";Expression={"{0:n2}" -f ($_.TotalPhysicalMemory / 1GB)}}
        
        $excel = $ComputerSystem.PSObject.Properties | Select-Object Name, Value | `
            Export-Excel    -ExcelPackage $excel `
                            -WorksheetName $Hostname `
                            -TableName "ComputerInfo_$HOstname" `
                            -StartRow $StartRow `
                            -StartColumn $StartColumn `
                            -Title "Computer Info" `
                            @titleParams `
                            -AutoSize `
                            -Numberformat Text `
                            -PassThru
        
        $StartColumn += 3

        ": Operating System"
        $OSInfo = $OS | Select-Object   Caption, `
                                        Organization, `
                                        @{Name="OS Architecture"; Expression={$_.OSArchitecture}}, `
                                        @{Name="Windows Directory";Expression={$_.WindowsDirectory}}, `
                                        @{Name="System Directory";Expression={$_.SystemDirectory}}
        
        $excel = $OSInfo.PSObject.Properties | Select-Object Name, Value | `
                Export-Excel    -ExcelPackage $excel `
                                -WorksheetName $Hostname `
                                -TableName "OSInfo_$hostname" `
                                -StartRow $StartRow `
                                -StartColumn $StartColumn `
                                -Title "OS Information:" `
                                @titleParams `
                                -AutoSize `
                                -Numberformat Text `
                                -PassThru

        $StartColumn += 3

        ": Logical Disks"
        $LogicalDisks = Get-CimInstance -CimSession $CIMSession -ClassName Win32_LogicalDisk | `
            Where-Object  {$_.DriveType -eq '3'} -ErrorAction SilentlyContinue

        $LDInfo = $LogicalDisks | Select-Object DeviceID, `
                                                VolumeName, `
                                                @{Name="Size";Expression={"{0:N2}" -f ($_.Size / 1GB)}}, `
                                                @{Name="Free Space";Expression={"{0:N2}" -f ($_.FreeSpace / 1GB)}}
        
        $excel = $LDInfo | Export-Excel -ExcelPackage $excel `
                                        -WorksheetName $HostName `
                                        -TableName "LogicalDisks_$HostName" `
                                        -StartRow $StartRow `
                                        -StartColumn $StartColumn `
                                        -Title 'Logical Disks:' `
                                        @titleParams `
                                        -AutoSize `
                                        -Numberformat Text `
                                        -PassThru
        
        $StartColumn += 5

        ": Processors"
        $Processors = Get-CimInstance -CimSession $CIMSession -ClassName Win32_Processor | `
            Select-Object   Manufacturer, `
                            Name, `
                            @{Name="Clock Speed GHz";Expression={"{0:n2}" -f ($_.MaxClockSpeed / 1KB)}}, `
                            @{Name="Address Width";Expression={$_.AddressWidth}}, `
                            @{Name="Cores";Expression={$_.NumberOfCores}}, `
                            @{Name="Logical Processors";Expression={$_.NumberOfLogicalProcessors}}

        $excel = $Processors | Export-Excel -ExcelPackage $excel `
                                            -WorksheetName $HostName `
                                            -TableName "Processors_$HostName" `
                                            -StartRow $StartRow `
                                            -StartColumn $StartColumn `
                                            -Title "Processors:" `
                                            @titleParams `
                                            -AutoSize `
                                            -Numberformat Text `
                                            -PassThru

        $StartColumn = 1
        $StartRow = 9

        #Document SQL Data
        $Instances = Get-ChildItem -Path "SQLSERVER:\SQL\$DNSHostName"
    
        foreach ($Instance in $Instances) {
            if (-not $Instance.InstanceName) {
                $InstName = $HostName
            } else {
                $InstName = $Instance.InstanceName              
            }
            Set-ExcelRange -Range $excel.Workbook.Worksheets[$HostName].Cells[$StartRow, $StartColumn] -FontSize 14 -Bold -Value $InstName
            $StartRow += 1

            ": SQL Server Info"
            $ServerInfo = $Instance | Select-Object -Property `
                        ComputerNamePhysicalNetBIOS, Edition, Version, ProductLevel, UpdateLevel, BuildClrVersionString, `
                        BackupDirectory, DefaultFile, DefaultLog, MasterDBPath, MasterLogPath, FileStreamLevel, `
                        InstanceName, LoginMode, MailProfile,  PhysicalMemory, Processors, ServiceAccount, ServiceInstanceID, SQLDomainGroup
            
            $excel = $ServerInfo.PsObject.Properties | Select-Object Name, Value | `
                            Export-Excel    -ExcelPackage $excel `
                                            -WorksheetName $HostName `
                                            -TableName "ServerInfo_$HostName_$InstName" `
                                            -StartRow $StartRow `
                                            -StartColumn $StartColumn `
                                            -Title "Server Info:" `
                                            @titleParams `
                                            -AutoSize `
                                            -Numberformat Text `
                                            -PassThru

            $StartColumn += 3
            
            ": SQL Server Roles"
            $ServerRoles = Invoke-Sqlcmd -Query "EXEC sp_ServerRoles" -Database master -ServerInstance $InstName -Encrypt Optional
            $excel = $ServerRoles | Select-Object name, sysadmin, securityadmin, serveradmin, setupadmin, processadmin, diskadmin, dbcreator, bulkadmin | `
                                    Export-Excel    -ExcelPackage $excel `
                                                    -WorksheetName $HostName `
                                                    -TableName "ServerRoles_$HostName_$InstName" `
                                                    -StartRow $StartRow `
                                                    -StartColumn $StartColumn `
                                                    -Title "Server Roles:" `
                                                    @titleParams `
                                                    -AutoSize `
                                                    -Numberformat Text `
                                                    -PassThru
            
            $StartColumn =1
            $StartRow += $ServerInfo.PSObject.Properties.Name.Count + 3

            ": SQL Database Info"
            $Databases = $Instance.Databases | Select-Object -Property Name, Owner, `
                                                @{Name="Primary File Path";Expression={$_.PrimaryFilePath}}, `
                                                @{Name="Recovery Model";Expression={$_.RecoveryModel}}, `
                                                Status   

            $excel = $Databases | Export-Excel  -ExcelPackage $excel `
                                                -WorksheetName $HostName `
                                                -StartRow $StartRow `
                                                -StartColumn $StartColumn `
                                                -Title "Databases:" `
                                                -TableName "Databases_$HostName_$instName" `
                                                @titleParams `
                                                -AutoSize `
                                                -Numberformat Text `
                                                -PassThru

            $StartColumn += 6
            
            ": Sql Logins"
            $sqlLogins = $Instance | Get-SqlLogin | Where-Object {$_.Name -notlike "##*"}

            $Logins = $sqlLogins | Select-Object -Property Name, LoginType, `
                                                    @{Name="Create Date";Expression={$_.CreateDate.ToShortDateString()}}, `
                                                    @{Name="Disabled";Expression={$_.IsDisabled}}, `
                                                    @{Name="Password Expires";Expression={$_.PasswordExpirationEnabled -eq $true}}, `
                                                    @{Name="Password Policy Enforced";Expression={$_.PasswordPolicyEnforced -eq $true}}
        
            $Logins | ForEach-Object {
                if ($_.LoginType -eq 'WindowsUser') {
                    $User = Get-ADUser $_.Name -Properties * -ErrorAction SilentlyContinue
                    if ($User.Enabled) {
                        $DomainStatus = "Enabled"
                    } else {
                        $DomainStatus = "False"
                    }
                } else {
                    $DomainStatus = "N/A"
                }
                $_ | Add-Member -MemberType NoteProperty -Name "DomainStatus" -Value $DomainStatus
            }
        
            $excel = $Logins | Export-Excel -ExcelPackage $excel `
                                            -WorksheetName $HostName `
                                            -StartRow $StartRow `
                                            -StartColumn $StartColumn `
                                            -Title "Logins:" `
                                            -TableName "Logins_$HostName_$InstName" `
                                            @titleParams `
                                            -AutoSize `
                                            -Numberformat Text `
                                            -PassThru

            $StartColumn += 8

            ": Sql User Mappings"
            $UserMappings = $sqlLogins.EnumDatabaseMappings() | `
                                Select-Object   LoginName, `
                                                @{Name="Database Name";Expression={$_.DBName}}, `
                                                @{Name="User Name";Expression={$_.username}}, `
                                                @{Name="Roles";Expression={$instance.Databases[$_.DBName].Users[$_.Username].EnumRoles() -join ', '}}

            $excel = $UserMappings | Export-Excel   -ExcelPackage $excel `
                                                    -WorksheetName $HostName `
                                                    -StartRow $StartRow `
                                                    -StartColumn $StartColumn `
                                                    -TableName "UserMappings_$HostName_$InstName" `
                                                    -Title "User Mappings:" `
                                                    @titleParams `
                                                    -AutoSize `
                                                    -Numberformat Text `
                                                    -PassThru

            $StartColumn += 5
            
            ": SQL User Permissions"   
            $Permissions = @()         
            foreach ($Database in $Databases) {
                $qry_DataBasePermissions = "
                Use [{0}]
                Go

                Select pr.type_desc, pr.name,
                    isnull (pe.state_desc, 'No permission Statements') as State,
                    isnull (pe.permission_name, 'No permission statements') as Permission
                From sys.database_principals as pr
                    left outer join sys.database_permissions as pe
                        on pr.principal_id = pe.grantee_principal_id
                Where pr.is_fixed_role = 0 and (pr.name NOT IN ('public', 'sys', 'INFORMATION_SCHEMA', 'guest','NT AUTHORITY\SYSTEM') ) 
                    and (pr.name not like '##%')
                    and (pr.type_desc <> 'DATABASE_ROLE') and (pe.permission_name <> 'CONNECT')
                Order By pr.name, type_desc;"
                
                $qry_DataBasePermissions = $qry_DataBasePermissions -f $Database.Name
                try {
                    $dbPermissions = Invoke-Sqlcmd -Query $qry_DataBasePermissions -ServerInstance $InstName -Encrypt Optional
                } catch {
                    throw $_
                }
                $dbPermissions = $dbPermissions | Select-Object @{Name="Database"; Expression={$Database.Name}}, `
                                                                @{Name="Type"; Expression={$_.type_desc}}, `
                                                                @{Name="Principal"; Expression={$_.name}}, State, Permission                                                            
                $Permissions += $dbPermissions
            }
            if ($Permissions) {
                $excel = $Permissions | Export-Excel    -ExcelPackage $excel `
                                                        -WorksheetName $HostName `
                                                        -StartRow $StartRow `
                                                        -StartColumn $StartColumn `
                                                        -TableName "Permissions_$Hostname_$instName" `
                                                        -Title "User (non-Role) Permissions" `
                                                        @titleParams `
                                                        -AutoSize `
                                                        -Numberformat Text `
                                                        -PassThru
            }    
        }
        ": Formatting Tables"
        $excel.Workbook.Worksheets[$HostName].Tables | ForEach-Object {
            ":: Formatting Table {0}" -f $_.Name
            $_.Address | Set-ExcelRange @TableParams
        }
    } else {
        "Server $DNSHostName is not online!"  
    }
}

End {
    If ($excel) {
        "Completed"
        "Closing Excel Package"
        if ($IsWindows) {
            "Opening Workbook"
            Close-ExcelPackage $excel -Show
        } Else {
            "Saving WorkBook. Open in your preffered Spreadsheet application (Note: Libre Calc will lose most formatting)"
            Close-ExcelPackage $excel
        }
    }
}