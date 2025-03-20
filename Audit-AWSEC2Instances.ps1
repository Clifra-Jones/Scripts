#Requires -Modules @{ModuleName = 'AWS.Tools.EC2'; ModuleVersion = '4.1.670'}
#Requires -Modules @{ModuleName = 'ImportExcel'; ModuleVersion = '7.8.9'}

Param(
    [string]$outputPath,
    [string]$Filename
)
$ErrorActionPreference  = 'Stop'

If (-not $outputPath) {
    $OutputPath = $PSScriptRoot
}

if(-not $Filename.EndsWith(".xlsx")) {
    $Filename += ".xlsx"
}

$WorkbookName = "{0}/{1}" -f $OutputPath, $Filename
if (Test-Path $WorkbookName) {
    Remove-Item $WorkbookName
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
    FontSize=9;
    WrapText=$true;
    VerticalAlign="top"
}

$excel = Export-Excel -Path $workbookName -PassThru
#$worksheetName = "EC2 Audit"
#$excel.Workbook.Worksheets["Sheet1"].Name = $worksheetName


$Regions = Get-AWSRegion | Where-Object {$_.Name -like "US*" -and $_.Name -notlike "*ISO*"}

foreach ($Region in $Regions) {    

    $StartRow = 1
    $StartColumn = 1   
    #Import-Module AWS.Tools.EC2
    $instances = (Get-EC2Instance -Region $Region.Region).instances 
    $SecurityGroups = Get-EC2SecurityGroup -Region $Region.Region

    if ($instances) {
        $worksheetName = $Region.Region
        [void](Add-Worksheet -ExcelPackage $excel -WorksheetName $worksheetName)
        if ($excel.Workbook.Worksheets['Sheet1']) {
            $excel.Workbook.Worksheets.Delete("Sheet1")
        }
    }

    foreach ($SecurityGroup in $SecurityGroups) {
        $groupId = $SecurityGroup.GroupId.Replace("-","")
        $groupData =    $SecurityGroup | Select-Object @{Name="Security Group Name"; e={$_.GroupName}}, `
                            @{Name="Security Group ID"; e={$_.GroupId}}, `
                            @{Name="Description"; e={$_.Description}}, `
                            @{Name="VPN ID"; e={$_.VpcId}}, `
                            @{Name="Inbound Rule Count"; e={$_.IpPermissions.Count}}, `
                            @{Name="Outbound Rule Count"; e={$_.IpPermissionsEgress.count}}
        $excel = $groupData | Export-Excel  -ExcelPackage $excel `
                                            -WorksheetName $worksheetName `
                                            -StartRow $StartRow `
                                            -StartColumn $StartColumn `
                                            -TableName $groupId `
                                            -Title "$($SecurityGroup.groupId) - $($SecurityGroup.GroupName)" `
                                            @titleParams `
                                            -AutoSize `
                                            -Numberformat Text `
                                            -PassThru `
                                            -WarningAction SilentlyContinue
                                            
        
        $StartRow += 4
        $StartColumn += 1
        $SgInstances = $instances | Where-object {$_.SecurityGroups.Where({$_.GroupId -eq $SecurityGroup.GroupId}) -ne $null}
        if ($SgINstances) {
            $instanceData = $SgInstances | Select-Object @{Name="Name"; e={$_.Tags.Where({$_.Key -like "Name"}).value}}, `
                                                @{Name="Instance Id"; e={$_.InstanceId}}, `
                                                @{Name="Instance Type"; e={$_.InstanceType}}
            $excel = $instanceData | Export-Excel   -ExcelPackage $excel `
                                                    -WorksheetName $worksheetName `
                                                    -StartRow $StartRow `
                                                    -StartColumn $StartColumn `
                                                    -TableName "$($groupId)Instances" `
                                                    -Title "Security Group Instances" `
                                                    @titleParams `
                                                    -AutoSize `
                                                    -Numberformat Text `
                                                    -PassThru `
                                                    -WarningAction SilentlyContinue
                                                    
            $StartRow += ($SgInstances.count + 3)
        }

        $IpPermissions = $SecurityGroup.IpPermissions
        $IpPermissionsData = $IpPermissions | Select-Object @{Name="Protocol"; e={($_.IpProtocol -in "-1","0") ? "All" : $_.IpProtocol}}, `
                                    @{Name="IP Ranges"; e={[System.String]::Join(", ", $_.IpRanges)}}, `
                                    @{Name="Port Ranges"; e={($_.fromPort -in "-1","0") ? "All" : $_.toPort - $_.fromPort ? "$($_.fromPort) - $($_.toPort)" : $_.FromPort}}, `
                                    @{Name="Descriptions"; e={[System.String]::Join(", ", $_.IPv4Ranges.Description)}}
        
        if ($IpPermissionsData) {
            $excel = $IpPermissionsData | Export-Excel -ExcelPackage $excel `
                                            -WorksheetName $worksheetName `
                                            -StartRow $StartRow `
                                            -StartColumn $StartColumn `
                                            -TableName "$($groupId)InboundRules" `
                                            -Title "Inbound Rules" `
                                            @titleParams `
                                            -AutoSize `
                                            -NumberFormat Text `
                                            -PassThru `
                                            -WarningAction SilentlyContinue
        
            $StartRow += ($IpPermissionsData.count + 3) 
        }
        $StartColumn = 1
    }
}
foreach ($worksheet in $excel.Workbook.Worksheets) {
    $worksheet.Tables | ForEach-Object {
        $_ | Set-ExcelRange @tableParams
    }
}

if ($excel) {
    "Completed"
    "Closing Excel Package"
    if ($isWindows) {
        "Opening Workbook"
        Close-ExcelPackage $excel -Show
    } else {
        "Saving workbook $WorkbookName. Open in you preferred Spreadsheet application."
        Close-ExcelPackage $excel
    }
}

