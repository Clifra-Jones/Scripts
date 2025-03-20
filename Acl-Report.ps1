
Param (
    [Parameter(
        Mandatory = $true,
        ValueFromPipeline = $true
    )]
    $Path,
    [switch]$includeInherited,
    [Parameter(
        Mandatory = $true
    )]
    [string]$reportName,
    [string]$outputFolder,
    [string]$ComputerName,
    [switch]$useSSL
)

#$errorActionPreference = "STOP"
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

if (-not $outputFolder) {
    $outputFolder = $PSScriptRoot
}
$outputPath = "{0}/{1}.xlsx" -f $outputFolder, $reportName
if (Test-Path $outputPath) {
    Remove-Item $outputPath -Force
}

$titleParams = @{
    TitleBold=$true;
    TitleSize=9;
}

$tableParams = @{
    BorderColor="black";
    BorderRight="thin";
    BorderLeft="thin";
    BorderTop="thin";
    BorderBottom="thin";
    FontSize=9
}

$excel = "ACL Report" | Export-Excel -Path $outputPath -WorksheetName $reportName -ClearSheet -PassThru
$worksheet = $excel.Workbook.Worksheets[$reportName]
$StartRow = 3
$StartColumn = 1

Set-ExcelColumn -Column 1 -StartRow 1 `
                -ExcelPackage $excel -WorksheetName $reportName `
                -FontSize 16 -Bold

# Script block to retrieve ACLs fro remote computers. 
# This constructs a simple object               

#Get ACLs
if ($computerName) {
    $PSSessionOptions = New-PSSessionOption -SkipCACheck 
    if ($useSSL) {        
        $PSSession = New-PSSession -ComputerName $computerName -SessionOption $PSSessionOptions -UseSSL -Port 5986
    } else {
        $PSSession = New-PSSession -ComputerName $ComputerName -SessionOption $PSSessionOptions
    }
    # As PS Remoting mucks up this object when it get serialized and deserialized, we are going to convert only the properties
    # we need to JSON and then convert them back. As not all servers have Powershell core installed we cannot handle enums properly, So
    # we will have to deal with that later on when we write to the worksheet.
    $rootACL = invoke-command -Session $PSSession -ScriptBlock { 
        Get-Acl -Path $using:Path | Select-Object Path, Owner, Group, Access, Audit, Sddl | ConvertTo-Json } | ConvertFrom-Json
    Write-Host "Getting Folder ACLs. This may take a while..." -ForegroundColor Yellow
    # For some reason the objects get mucked up if we try to runthe entire process ont he remote computer.
    # Therefor we will get the Child directory items, then loop thorugh them and get the ACLs remotely.
    $Children = Invoke-Command -Session $PSSession -ScriptBlock { Get-ChildItem -Directory -Recurse -Path $using:Path | Sort-Object FullName}
    $ChildACLs = $Children | ForEach-Object {
        Invoke-Command -Session $PSSession -ScriptBlock {
            Get-Acl -Path $using:_.FullName | Select-Object Path, Owner, Group, Access, Audit, Sddl | ConvertTo-Json
        } | ConvertFrom-Json
    }
} else {
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
    $beginRow = $StartRow                                    
    $Props | Foreach-Object {
        $worksheet.Cells.Item($script:StartRow, $script:StartColumn).value = $_.Name
        $worksheet.Cells.Item($script:StartRow, ($script:StartColumn +1)).value = $_.Value
        $script:StartRow += 1
    }
    $endRow = $StartRow - 1
    $range = "{0}:{1}" -f $worksheet.Cells.Item($beginRow,$script:StartColumn).Address, $worksheet.Cells.Item($endRow, $script:StartColumn)
    Set-ExcelRange -Worksheet $worksheet -Range $range -Bold -FontSize 9
    $range = "{0}:{1}" -f $worksheet.Cells.Item($beginRow, $script:StartColumn +1).Address, $worksheet.Cells.Item($endRow, $script:StartColumn + 1)
    Set-ExcelRange -Worksheet $worksheet -Range $Range -FontSize 9
}

function Write-AccessList() {
    Param ($AccessList)
    $Column = $script:StartColumn + 1
    $StartRange = $worksheet.Cells.Item($script:StartRow, $Column).Address
    "Indentity","Type","Inherited","Rights","Inheritence Flags","Propagation Flags" | Foreach-Object {
        $worksheet.Cells.Item($script:StartRow,$Column).value = $_
        $Column += 1
    }
    $endRange = $Worksheet.Cells.Item($script:StartRow, $Column - 1)
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
}

foreach ($ACL in $Acls) {
    $Folder = $Acl.Path.Split("::")[1]
    $Index = ($ACLs -is [array]) ? $Acls.IndexOf($acl) : 0
    Write-Progress -Activity "Getting ACL" -Status "Folder: $Folder" -PercentComplete ($index / $Acls.Count * 100) -id 1
    if ($Index -eq 0) {
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
    if ($ComputerName) {
        $FileACLs = Invoke-Command -Session $PSSession -ScriptBlock {
            Get-ChildItem -File -Path $using:Folder | Sort-Object FullName | `
                Get-Acl | Select-Object Path, Owner, Group, Access, Audit, Sddl | ConvertTo-Json } | ConvertFrom-Json
    } else {
        $FileACLs = Get-ChildItem -File -Path $folder | Sort-Object FullName | Get-Acl
    }
    foreach ($fileACL in $FileACLs) {
        $file = $fileAcl.Path.split("::")[1]
        $index = ($FileACLs -is [array]) ? $FileACLs.indexOf($FileACL) : 0
        Write-Progress -Activity "Get File ACLs" -Status "File: $File" -PercentComplete ($index / $FileACLs.count * 100) -id 2
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
        Write-Progress -Activity "Get File ACLs" -id 2 -Completed 
    }
    Write-Progress --Activity "Getting ACL" -id 1 -Completed
}

Close-ExcelPackage $excel -Show