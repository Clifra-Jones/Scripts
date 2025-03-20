![Balfour Logo](https://www.balfourbeattyus.com/Balfour-dev.allata.com/media/content-media/2017-Balfour-Beatty-Logo-Blue.svg?ext=.svg)

## Windows ACL Report

This script creates an Excel report of all Access Control List entries for a folder tree.

The script can be run on a local computer or on a remote computer or file share.

!!! Warning
    This script can run for a very long time if run against a very deep directory tree.
    Running this under an account that is subject the Multi-Factor authentication can cause the authentication token to time out.
    You should run this script under an account that has Read and Read Permissions rights to the entire folder tree that is not subject to MFA.

This script requires PowerShell Core 6.0.0 or above. 7.0.0 or above is preferred.

#### Required Modules
ImportExcel

#### Remote Computers

For remote computers this script can run under two different modes.

- **PowerShell Remoting**
    Commands are executed on the remote computer and data is returned. This requires PSRemoting be enabled on the target computer. WinRM over HTTPS is the preferred method of enabling PSRemoting. If WinRM over HTTPS is enabled specify the -useSSL parameter to connect using HTTPS. This method is useful on computers that do not have file shares enabled.
- **PSDrive**
    A windows share is connected as a PSDrive and the files are access through the drive. This method is a bit slower in gathering the ACLs but will work if PSRemoting is not enabled. This also is the only method for reporting on an AWS FsX filesystem or other file systems not run on a Windows Server.

#### Parameters

The following parameters are used with this script.

- **Path**
    Path from the root of the drive to the folder being reported on.
    If reporting on the local machine this must contain the drive letter.
    If reporting on a remote machine and -usePSDrive is not specified it must also include the drive letter.
    If usePSDrive is specified then this is the share name.

- **includeInherited**
    Include all inherited permissions on child objects in the report. By default only child objects with non-inherited permissions are included.

!!! Warning
    Enabling this parameter can create a very, very large report with a lot of duplicate information.

- **reportName**
    Filename of the report (without extension)
    If the file already exists it will be overwritten.

- **outputFolder**
    Folder to store the report in.

- **ComputerName**
    Name of the remote computer.

- **useSSL**
    Use SSL (HTTPS) to connect to remote powershell. (will be ignored if usePSDrive is specified)

- **skipCACheck**
    If server certificate is self signed skip the CA check on connection. Only applicable if useSSL is specified.

- **usePSDrive**
    Read files using a PS drive. This will be slower but can be used where remote powershell is unavailable. i.e. reporting on an AWS FsX server.

- **Credentials**
    Credentials to connect to the remote computer. If not specified you will be prompted for them. Credential must be supplied as a PSCredential object.

- **useIntegratedSecurity**
    Use the current logged in user to connect to the remote computer.

#### Script Source

```powershell
#Requires -Modules @{ModuleName = "ImportExcel"; ModuleVersion = '7.4.1'}

<# 
    SYNOPSYS
        Generate Report on ACLs in a given folder on a given server.

    DESCRIPTION:
        Generates a report in excel format of the ACLs on a given directory tree. The report can be run on the local computer (fastest) or a remote computer.
        Remote computer reporting can be performed with 2 operating modes. 
        Using PSRemoting is the most efficient way. You specify the computername, the full path to the directory to be reported on, whether to use SSL 
        for the remote connection and specify credentials to connect.
        Using PSDrive you specify the computer name, Path is the share name and specify credentials to connect to the share (this is less efficient).

    PARAMETERS:

    Path: 
        Path from the root of the drive to the folder being reported on.
        If reporting on the local machine this must contain the drive letter.
        If reporting on a remote machine and -usePSDrive is not specified it must also include the drive letter.
        If using -usePSDrive is specified then this is the share name.

    includeInherited:
        Include all inherited permissions on child objects in the report. By default only child object with non-inherited permissions are included.
    
    reportName:
        Filename of the report (without extension)
    
    outputFolder:
        Folder to store the report in.
    
    ComputerName:
        Name of the remote computer.

    useSSL:
        Use SSL to connect to remote powershell. (will be ignored if usePSDrive is specified)
    
    skipCACheck:
        If server certificate is self signed skip the CA check on connection.

    usePSDrive:
        Read files using a PS drive. This will be slower but can be used where remote powershell is unavailable. i.e. reporting on an AWS FsX server.
    
    Credentials:
        Credentials to connect to the remote computer. If not specified you will be prompted for them

    useIntegratedSecurity:
        Use the current logged in user to connect to the remote computer.
#>
Param (
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true
    )]
    [string]$Path,
    [switch]$includeInherited,
    [Parameter(
        Mandatory = $true
    )]
    [string]$reportName,
    [string]$outputFolder,
    [string]$ComputerName,
    [switch]$useSSL,
    [switch]$SkipCACheck,
    [switch]$usePSDrive,
    [PSCredential]$Credentials,
    [switch]$useIntegratedSecurity
)

$errorActionPreference = "stop"
# This function converts the FileSystemRights object into a more human readable format.
function Get-FileSystemRights() {
    Param(
        $FileSystemRights
    )

    $accessMask = [ordered]@{
        [uint32]'0x80000000' = 'GenericRead'
        [uint32]'0x40000000' = 'GenericWrite'
        [uint32]'0x20000000' = 'GenericExecute'
        [uint32]'0x10000000' = 'GenericAll'
        [uint32]'0x02000000' = 'MaximumAllowed'
        [uint32]'0x01000000' = 'AccessSystemSecurity'
        [uint32]'0x00100000' = 'Synchronize'
        [uint32]'0x00080000' = 'WriteOwner'
        [uint32]'0x00040000' = 'WriteDAC'
        [uint32]'0x00020000' = 'ReadControl'
        [uint32]'0x00010000' = 'Delete'
        [uint32]'0x00000100' = 'WriteAttributes'
        [uint32]'0x00000080' = 'ReadAttributes'
        [uint32]'0x00000040' = 'DeleteChild'
        [uint32]'0x00000020' = 'Execute/Traverse'
        [uint32]'0x00000010' = 'WriteExtendedAttributes'
        [uint32]'0x00000008' = 'ReadExtendedAttributes'
        [uint32]'0x00000004' = 'AppendData/AddSubdirectory'
        [uint32]'0x00000002' = 'WriteData/AddFile'
        [uint32]'0x00000001' = 'ReadData/ListDirectory'
    }

    $simplePermissions = [ordered]@{
        [uint32]'0x1f01ff' = 'FullControl'
        [uint32]'0x0301bf' = 'Modify'
        [uint32]'0x0200a9' = 'ReadAndExecute'
        [uint32]'0x02019f' = 'ReadAndWrite'
        [uint32]'0x020089' = 'Read'
        [uint32]'0x000116' = 'Write'
    }

    if ($FileSystemRights -is [System.Enum]) {
        $fsr = $FileSystemRights.value__
    } else {
        $fsr = $FileSystemRights
    }

    $permissions = @()

    $permissions += $simplePermissions.Keys | ForEach-Object {
        if (($fsr -band $_) -eq $_) {
            $simplePermissions[$_]
            $fsr = $fsr -band (-bnot $_)
        }
    }

    $permissions += $accessMask.Keys | Where-object { $fsr -band $_} | ForEach-Object {
        $accessMask[$_]
    }

    return $permissions
}

If (-not $useIntegratedSecurity.IsPresent) {
    if (-not $Credentials) {
        $Credentials = Get-Credential
    }
}

if (-not $outputFolder) {
    $outputFolder = $PSScriptRoot
}

$outputPath = "{0}/{1}.xlsx" -f $outputFolder, $reportName

if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
}

# Create the Excel package putting a title into Row 1, column 1.
$excel = "ACL Report" | Export-Excel -Path $outputPath -WorksheetName $reportName -ClearSheet -PassThru
$worksheet = $excel.Workbook.Worksheets[$reportName]
$StartRow = 3
$StartColumn = 1

# Set the title to 16 point size and bold.
Set-ExcelColumn -Column 1 -StartRow 1 `
                -ExcelPackage $excel -WorksheetName $reportName `
                -FontSize 16 -Bold

# Script block to retrieve ACLs. 
# This constructs two object. The rootACL and a collection of child ACLs.               

if ($computerName) {
    if ($usePSDrive) {
        Write-Host "We are running in PSDrive Mode" -ForegroundColor Yellow
        $sharepath = "\\{0}\{1}" -f $ComputerName, $Path
        New-PSDrive -Name "srvr" -Root $sharepath -PSProvider FileSystem -Credential $Credentials

        $rootACL = Get-Acl -Path srvr:\ | Select-Object Path, Owner, Group, Access, Audit, Sddl
        Write-Host "Getting remote folders. This may take a while..." -ForegroundColor Yellow
        $Children = Get-ChildItem -Directory -Recurse -Path srvr:\ | Sort-Object FullName
        $ChildAclList = New-Object System.Collections.Generic.List[PSObject]
        $Children | Foreach-Object {
            Write-Host ("Getting ACL for Folder: {0}" -f $_.FullName) -ForegroundColor Yellow
            $Acl = Get-Acl -Path $_.FullName | Select-Object Path, Owner, Group, Access, Audit, Sddl
            $ChildAclList.Add($Acl)
        }
        $ChildACLs = $ChildAclList.toArray()        
    } else {
        if ($SkipCACheck) {
            $PSSessionOptions = New-PSSessionOption -SkipCACheck 
        } else {
            $PSSessionOptions= New-PSSessionOption
        }

        if ($useSSL) {        
            $PSSession = New-PSSession -ComputerName $computerName -SessionOption $PSSessionOptions -UseSSL -Port 5986 -Credential $Credentials
        } else {
            $PSSession = New-PSSession -ComputerName $ComputerName -SessionOption $PSSessionOptions -Credential $Credentials
        }
        # As PS Remoting mucks up this object when it get serialized and deserialized, we are going to convert only the properties
        # we need to JSON and then convert them back. As not all servers have Powershell core installed we cannot handle enums properly, So
        # we will have to deal with that later on when we write to the worksheet.
        $rootACL = invoke-command -Session $PSSession -ScriptBlock { 
            Get-Acl -Path $using:Path | Select-Object Path, Owner, Group, Access, Audit, Sddl | ConvertTo-Json } | ConvertFrom-Json
        Write-Host "Getting remote folders. This may take a while..." -ForegroundColor Yellow
        # For some reason the objects get mucked up if we try to run the entire process on the remote computer.
        # Therefor we will get the Child directory items, then loop through them and get the ACLs remotely.    
        $Children = Invoke-Command -Session $PSSession -ScriptBlock { Get-ChildItem -Directory -Recurse -Path $using:Path | Sort-Object FullName}    
        $ChildACLs = $Children | ForEach-Object {
            write-Host ("Getting ACL for Folder: {0}" -f $_.FullName)
            Invoke-Command -Session $PSSession -ScriptBlock {
                Get-Acl -Path $using:_.FullName | Select-Object Path, Owner, Group, Access, Audit, Sddl | ConvertTo-Json
            } | ConvertFrom-Json
        }
    }
} else {
    # We are running this locally on the target computer.
    $rootACL = Get-Acl $Path
    $childACLs = Get-ChildItem -Directory -Recurse $Path | Sort-Object FullName | Get-Acl
}

$Acls = @()
$Acls += $rootACL
$Acls += $childACLs

function Write-ACL() {
    Param ($ACL)

    $Props = ($ACL | Select-Object @{Name="Path";Expression={$_.Path.Split("::")[1]}}, `
                                    Owner, @{Name="Primary Group";Expression={$_.Group}}).PSObject.Properties | Select-Object Name, Value
    $beginRow = $script:StartRow                                    
    $Props | Foreach-Object {
        $worksheet.Cells.Item($script:StartRow, $script:StartColumn).value = $_.Name
        $worksheet.Cells.Item($script:StartRow, ($script:StartColumn +1)).value = $_.Value
        $script:StartRow += 1
    }
    $endRow = $script:StartRow - 1
    $range = "{0}:{1}" -f $worksheet.Cells.Item($beginRow,$script:StartColumn).Address, $worksheet.Cells.Item($endRow, $script:StartColumn)
    Set-ExcelRange -Worksheet $worksheet -Range $range -Bold -FontSize 9
    $range = "{0}:{1}" -f $worksheet.Cells.Item($beginRow, $script:StartColumn +1).Address, $worksheet.Cells.Item($endRow, $script:StartColumn + 1)
    Set-ExcelRange -Worksheet $worksheet -Range $Range -FontSize 9
    #Write-Host $script:StartRow -ForegroundColor Yellow
}

function Write-AccessList() {
    Param ($AccessList)
    $Column = $script:StartColumn + 1
    $StartRange = $worksheet.Cells.Item($script:StartRow, $Column).Address
    "Identity","Type","Inherited","Rights","Inheritance Flags","Propagation Flags" | Foreach-Object {
        $worksheet.Cells.Item($script:StartRow,$Column).value = $_
        $Column += 1
    }
    $endRange = $Worksheet.Cells.Item($script:StartRow, $Column - 1).Address
    Set-ExcelRange -Worksheet $worksheet -Range "$($StartRange):$($endRange)" -Bold -Underline -FontSize 9
    $script:StartRow += 1

    $Column = $script:StartColumn +1
    $startRange = $worksheet.Cells.Item($script:StartRow,$Column).Address
    # Here we deal with the possibility we are getting an object from PSRemoting that we ran through JSON conversion.
    # We are casting the Enum value as System.Security.AccessControl.AccessControlType.
    # This will work even if the value is an integer (from JSON) or the original Enum value.
    $AccessList | Select-Object IdentityReference, `
                                @{Name="AccessControlType";Expression={$_.AccessControlType -as [System.Security.AccessControl.AccessControlType]}}, `
                                IsInherited, `
                                @{Name="Rights";Expression={(Get-FileSystemRights $_.FileSystemRights) -join ", "}}, `
                                @{Name="Inheritance Flags";Expression={$_.InheritanceFlags -as [System.Security.AccessControl.InheritanceFlags]}}, `
                                @{Name="Propagation Flags";Expression={$_.PropagationFlags -as [System.Security.AccessControl.PropagationFlags]}} | `
                Foreach-Object {
                    $Column = $script:StartColumn +1
                    $_.PSObject.Properties | foreach-Object {
                        $worksheet.Cells.Item($script:StartRow, $Column).Value = $_.value
                        $column += 1
                    }
                    $script:StartRow += 1
                }
    $endRange = $worksheet.Cells.Item($script:Startrow -1, $Column -1).address
    Set-ExcelRange -Worksheet $Worksheet -Range "$($startRange):$($endRange)" -FontSize 9
    # Uncomment below for debugging row placement.
    #Write-Host $script:StartRow
}

foreach ($ACL in $Acls) {
    $Folder = $Acl.Path.Split("::")[1]
    # Get the index of the current ACL in the array, else set index to 0.
    $Index = ($ACLs -is [array]) ? $Acls.IndexOf($acl) : 0
    <#
    Code for writing progress bar. Decided not to use it.
    #Write-Progress -Activity "Getting ACL" -Status "Folder: $Folder" -PercentComplete ($index / $Acls.Count * 100) -id 1
    #>
    Write-Host ("Processing ACLs for folder {0}" -f $Folder) -ForegroundColor Yellow
    if ($Index -eq 0) {
        # Index 0 corresponds to the rootACL.
        $AccessList = $Acl.Access
    } else {
        if ($includeInherited) {
            $AccessList = $Acl.Access
        } else {
            $AccessList = $Acl.Access | Where-Object {$_.IsInherited -eq $false}
        }
    }                                   
    if ($AccessList) {
        Write-ACL $ACL
        Write-AccessList $AccessList          
        $StartRow += 1    
    } 
    # Process file ACLs for this folder.
    if ($ComputerName) {
        if ($usePSDrive) {
            # As the path in the ACL now contains a UNC path we cannot use this to get the child items.
            # Therefor we will connect a new PSDrive to the folder path to get the file ACLs.
            # This PSdrive must be removed so that the name won't conflict. the next time through the loop.
            if ($folder.EndsWith("\")) {
                $Folder = $Folder -replace ".$"
            }
            New-PSDrive -Name "Fldr" -Root $Folder -PSProvider FileSystem -Credential $Credentials | Out-Null
            $FileACLs = Get-ChildItem -File -Path Fldr:\ | Sort-Object FullName | `
                Get-Acl | Select-Object Path, Owner, Access, Audit, Sddl -ErrorAction SilentlyContinue
            Remove-PSDrive Fldr | Out-Null                
        } else {
            $FileACLs = Invoke-Command -Session $PSSession -ScriptBlock {
                Get-ChildItem -File -Path $using:Folder | Sort-Object FullName | `
                    Get-Acl | Select-Object Path, Owner, Group, Access, Audit, Sddl | ConvertTo-Json } | ConvertFrom-Json
        }
    } else {
        $FileACLs = Get-ChildItem -File -Path $folder | Sort-Object FullName | Get-Acl
    }

    foreach ($fileACL in $FileACLs) {
        $file = $fileAcl.Path.split("::")[1]
        <#
        Code for writing a progress bar. Decided not to use it.
        $index = ($FileACLs -is [array]) ? $FileACLs.indexOf($FileACL) : 0
        Write-Progress -Activity "Get File ACLs" -Status "File: $File" -PercentComplete ($index / $FileACLs.count * 100) -id 2
        #>
        Write-Host ("Getting File ACL for file: {0}" -f $file)
        if ($includeInherited) {
            $AccessList = $fileAcl.Access
        } else {
            $AccessList = $fileAcl.Access | Where-Object {$_.IsInherited -eq $false}
        }

        if ($AccessList) {
            Write-ACL $fileAcl
            Write-AccessList $AccessList
            $StartRow += 1
        }
        #Write-Progress -Activity "Get File ACLs" -id 2 -Completed 
        
    }
    #Write-Progress --Activity "Getting ACL" -id 1 -Completed
}

# Close the Excel package and display the report.
Close-ExcelPackage $excel -Show
```
