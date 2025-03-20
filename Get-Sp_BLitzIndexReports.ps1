#Requires -Modules SQLServer, ImportExcel

Param(
    [string]$SQLServer,
    [PSCredential]$Creds,
    [array]$Databases,
    [string]$OutputFolder,
    [string]$OutputFilename
)

function ExecSQL ($Server, $query, [PSCredential]$Credentials) {
    if ($Credentials) {
        $result = Invoke-Sqlcmd -ServerInstance $Server -Credential $Credentials -Query $query
    } else {
        $result = Invoke-Sqlcmd -ServerInstance $Server -Query $query
    }

    return $result
}

$OutputPath = $OutputFolder + "/" + $OutputFilename
if (Test-Path -Path $OutputPath) {
    Remove-Item -Path $OutputPath
}

If (-not $Databases) {
    $Databases = ExecSQL -Server $SQLServer -Credentials $Creds -query "Select Name from sys.databases"
}

$excel = Export-Excel -Path $OutputPath -PassThru -WorksheetName $Databases[0].name

foreach ($Database in $Databases) {
    $query = "Exec sp_BlitzIndex @DatabaseName = '{0}'" -f $Database.Name
    $blitzResult = ExecSQL -Server $SQLServer -Credentials $Creds -query $query
    $excel = $blitzResult | Export-Excel -ExcelPackage $excel -WorksheetName $Database.Name -PassThru
}

Close-ExcelPackage $excel
