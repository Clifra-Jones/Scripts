$SQLServers = Import-Csv ../AWSSqlServers.csv

$SheetName = "SQL Servers"
if (Test-Path ./SQLServers.xlsx) {
    Remove-Item ./SQLServers.xlsx -Force
}

$excel = Export-Excel -WorksheetName $SheetName -Path .\SQLServers.xlsx -PassThru 
$Row = 1
foreach ($SqlServer in $SqlServers) {
    $excel = $SqlServer | Select-Object Name, InstanceType, Platform | Export-Excel -ExcelPackage $excel -WorksheetName $SheetName -StartRow $row -PassThru
    $Filter = [Amazon.EC2.Model.Filter]::New('attachment.instance-id', $SQLServer.InstanceId)
    if ($SqlServer.profile -ne "default") {
        Set-AWSCredential -ProfileName $SqlServer.profile
    }
    $Volumes = Get-EC2Volume -Filter $Filter
    $excel = $Volumes | Select-Object VolumeType, Size | Export-Excel -ExcelPackage $excel -WorksheetName $SheetName -StartRow $Row -StartColumn 4 -PassThru
    $Row += $Volumes.Count + 4
}

Close-ExcelPackage $excel
