#Requires -Modules SQLServer

Param (
    [string]$ServerInstance,
    [PSCredential]$creds
)

$SQL = "Select Name from sys.databases Where database_id > 4"

$Databases = Invoke-Sqlcmd -ServerInstance $ServerInstance -Query $SQL -Credential $creds

$ExtProps = $Databases | ForEach-Object {
    $sql = "Select Name, Value from sys.extended_properties"

    $results = Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $_.Name -Query $sql -Credential $creds
    foreach ($result in $results) {
        $result | Add-Member -MemberType NoteProperty -Name "Database" -Value $_.Name        
    }

    return $results
}

Write-Output $ExtProps | Format-Table
