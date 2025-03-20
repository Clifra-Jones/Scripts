# Document SQL servers on the network
#
# Author: Cliff Williams
# Revised: 3/5/2020
#
# Overview: Document SQL server installations. Outputs and Excel workbook. If multiple servers are supplied each will be documented
#           on a separate worksheet.
#
# Parameters:
#   SQLServer:
#       Required: True
#       Type: String
#       Accepts Pipeline input: True
#       Comment:    A single server name can be supplied on the command line or an array of server names can be supplied on the pipeline.
#                   When multiple names are supplied each server will be documented on a new worksheet
#
#   OutputFolder:
#       Required: False
#       Type: String
#       Default Value: Current folder
#       Comment:    Folder to save the created Excel workbook to. If not supplied the current script folder is used.
#
#  Dependencies
#       SQLServer module
#       ImportExcel module
#       WMI access to the server. Make sure WMI is allowed through any firewalls.
#       SYSAdmin access to the SQL servers.
#
#   Examples:
#       Document a single SQL server.
#       Document_SQLServer.ps1 -SQLServer 'SQLserver01' -OutputFolder 'c:\Docs'
#
#       Document Multiple SQL servers.
#       "SQLServer01","SQLServer01" | Document_SQLServer.ps1 -OutputFolder 'c:\docs'
#
#       Use ActiveDirectory to get a list of server to document.
#       (get-adcomputer -searchBase 'OU=servers,OU=MainOffice,DC=foo,dc=local' -filter {Name -like "*SQL*"}).Name | Document_SQLServer -OutputFile 'c:\docs'
#
Param (
    [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
    [string]$SqlServer,
    [string] $OutputFolder
)

Begin {
    #Uncomment the line below to stop script executing on any errors.
    #$ErrorActionPreference = "STOP"

    Import-Module sqlserver
    Import-Module ImportExcel

    if (-not $OutputFolder) {
        $OutputFolder = (Get-Location).Path
    }
    
    $FileName = "$OutputFolder\SQLDocs.xlsx"
    If (Test-Path $FileName) {
        Remove-Item $FileName
    }

    $startRow = 1
    $StartColumn = 1
  
}

Process {

    if (Test-Connection $SqlServer -Quiet -Count 2) {
        #Document Server Information
        #
        # This process required WMI access to the servers. Insure WMI access is granted through firewalls and security groups.
        #
        

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

        "Documenting: $SqlServer"
        
        #Verify WMI connection
        try {
            $OS = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $SqlServer 
        } catch {
            "Server is unavailable. Please insure WMI access is granted to this server from this computer."
            exit
        }

        #Verify the connection to the SQL Server
        try  {Get-SqlInstance -ServerInstance $sqlserver}
        catch {
            "Cannot connect to SQL server instance. Insure the account this script is running under is a sysadmin"
            return
        }

        ":  Computer System"
        $ComputerSystem =  Get-WmiObject -Class Win32_ComputerSystem -ComputerName $SqlServer | `
            Select-Object Domain, Manufacturer, Model, @{n="Owner";e={$_.PrimaryOwnerName}}, `
                          @{n="Memory";e={"{0:n2}" -f ($_.TotalPhysicalMemory / 1GB)}} 
        
        $excel = $ComputerSystem.PsObject.Properties | Select-Object Name, Value | `
            Export-excel -Path $FileName -WorksheetName $SqlServer -TableName ComputerInfo -StartRow $startRow `
                -StartColumn $StartColumn -Title "Computer Info:" @titleParams -AutoSize -Numberformat Text -PassThru
        
        $StartColumn += 3

        ":  Operating System"
        $OSInfo = $OS | Select-Object Caption, Organization, @{n="OS Architecture";e={$_.OSArchitecture}}, `
            @{n="windows Directory";e={$_.WindowsDirectory}}, @{n="System Directory";e={$_.SystemDirectory}}
        
        $excel = $OSInfo.PsObject.Properties | Select-Object Name, Value | `
            Export-Excel -ExcelPackage $excel -WorksheetName $SqlServer -TableName OSInfo -StartRow $startrow -StartColumn $StartColumn `
                -Title "OS Information:" @titleParams -AutoSize -Numberformat Text -PassThru
        
        $StartColumn += 3

        ":  Logical Disks"
        $LogicalDisks = Get-WmiObject -Class Win32_LogicalDisk -ComputerName $SqlServer | `
            Where-Object {$_.DriveType -eq '3'} -ErrorAction SilentlyContinue
        
        $LDInfo = $LogicalDisks | Select-Object DeviceID, VolumeName, @{n="Size";e={"{0:N2}" -f ($_.Size / 1GB)}}, `
            @{n="Free Space";e={"{0:N2}" -f ($_.FreeSpace / 1GB)}}

        $excel = $LDInfo | Export-Excel -ExcelPackage $excel -WorksheetName $SqlServer -TableName LogicalDrives -StartRow $startRow `
            -StartColumn $StartColumn -Title "Logical Drives:" @titleParams -AutoSize -Numberformat Text -PassThru
        
        $StartColumn += 5

        ":  Processors"
        $Processors = Get-WmiObject -Class Win32_Processor -ComputerName awssqlprd01 | Select-Object Manufacturer, Name,  `
            @{n="Clock Speed GHz";e={"{0:n2}" -f ($_.MaxClockSpeed / 1KB)}}, @{n="Address Width";e={$_.AddressWidth}}, `
            @{n="Cores";e={$_.NumberOfCores}}, @{n="Logical Processors";e={$_.NumberOfLogicalProcessors}}
        
        $excel = $Processors | Export-Excel -ExcelPackage $excel -WorksheetName $SQLServer -TableName Processors -StartRow $startRow `
            -StartColumn $StartColumn -Title "Processors:" @titleParams -Numberformat Text -AutoSize -PassThru
      
        $StartColumn = 1
        $startRow = 9

        
        #Document SQL Data
        $Instance = Get-ChildItem -Path "SQLSERVER:\SQL\$SQLServer" 

        ":  SQL Server Info"
        $ServerInfo = $Instance| Select-Object -Property `
                ComputerNamePhysicalNetBIOS, Edition, Version, ProductLevel, UpdateLevel, BuildClrVersionString, `
                BackupDirectory, DefaultFile, DefaultLog, MasterDBPath, MasterLogPath, FileStreamLevel, `
                InstanceName, LoginMode, MailProfile,  PhysicalMemory, Processors, ServiceAccount, ServiceInstanceID, SQLDomainGroup

        $excel = $ServerInfo.PsObject.Properties | Select-Object Name, Value | `
            Export-Excel -ExcelPackage $excel -WorksheetName $SQLSERVER -TableName ServerInfo -StartRow $StartRow `
                -Title "ServerInfo:" @titleParams -AutoSize -Numberformat Text -PassThru 
        
        $StartColumn += 3
        
        ":  Database Info"
        $Databases = $Instance.Databases | Select-Object -Property Name, Owner, PrimaryFilePath, RecoveryModel, Status

        $excel = $databases | Export-Excel -ExcelPackage $excel -WorksheetName $SqlServer -StartRow $StartRow -StartColumn $StartColumn `
            -TableName Databases -AutoSize -Title "Databases:" @titleParams -PassThru

        $startColumn += 6

        ":  SQL Logins"
        $sqlLogins = $Instance | Get-SqlLogin |Where-Object {$_.Name -notlike "##*"}

        $Logins = $sqlLogins | Select-Object -Property Name, LoginType, @{n="CreateDate";e={$_.CreateDate.ToShortDateString()}}, `
            IsDisabled, PasswordExpirationEnabled, PasswordPolicyEnforced

        $excel = $Logins | Export-Excel -ExcelPackage $excel -WorksheetName $SqlServer -Startrow $startRow -StartColumn $StartColumn `
            -TableName Logins -AutoSize -Title "Logins:" @titleParams -PassThru
        
        $StartColumn += 7
        
        ":  User Mappings"
        $UserMappings =  $SQLlogins | ForEach-Object {$_.EnumDatabaseMappings()} | Select-Object LoginName, DBName, UserName, `
            @{n="Roles";e={$instance.Databases[$_.DBName].Users[$_.UserName].EnumRoles() -join ', '}}

        $excel = $UserMappings | Export-Excel -ExcelPackage $excel -WorksheetName $SqlServer -Startrow $StartRow -StartColumn $StartColumn `
            -TableName UserMappings -AutoSize -Title "User Mappings:" @titleParams -PassThru

        $excel.Workbook.Worksheets[$SqlServer].Tables | ForEach-Object{
            $_.Address | Set-ExcelRange @TableParams
        }
    } else {
        "Server $SqlServer is not online!"
    }

}

End {
    If ($excel) {
        "Completed"
        "Closing Excel Package"
        "Opening Workbook"
        Close-ExcelPackage $excel -Show
    }
}

