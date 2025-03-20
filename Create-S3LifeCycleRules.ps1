$ExcludedPrefixes = @(
    "AWSHYPETL/",
    "AWSHYPETL01/",
    "DCSCCM01/"
    "FileGatewayBackups/",
    "HQVSVSQL05/"
    "OCISQLPRD01/"
    "DALLAPPS/"
    "AWSSQLDWDEV01/"
)

$Prefixes = Get-S3Folder -BucketName bb-sql-backups -Folders |Where-Object {$_.key -notin $ExcludedPrefixes}

$Rules = (Get-S3LifecycleConfiguration -BucketName bb-sql-backups).rules

foreach ($Prefix in $Prefixes) {
    $NewRule = [Amazon.S3.Model.LifecycleRule]@{
        Expiration = @{
            Days = 2
        }
        Id = $Prefix.Key.Replace("/","")
        Filter = @{
            LifecycleFilterPredicate = [Amazon.S3.Model.LifecyclePrefixPredicate]@{
                "Prefix" = $Prefix.Key
            }
        }
        Status = "Enabled"
    }

    $Rules.Add($NewRule)
}

Write-S3LifecycleConfiguration -BucketName bb-sql-backups -Configuration_Rule $Rules -Region us-east-1 -Verbose