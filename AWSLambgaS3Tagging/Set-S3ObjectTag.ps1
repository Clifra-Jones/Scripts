#requires -Modules @{ModuleName='AWS.Tools.S3'; ModuleVersion='4.1.444'}
#Requires -Modules @{ModuleName='AWS.Tools.Common';ModuleVersion='4.1.444'}

$Tag = [Amazon.s3.Model.Tag]::New()

$Bucket = $LambdaInput.Records[0].s3.bucket.name
$Key = $LambdaInput.Records[0].s3.Object.key

if ($Key -like "*.trn") {
    $Tag.Key = "BackupType"
    $Tag.Value = "Log"

} elseif($Key -like "*FULL*") {
    $Tag.Key = "BackupType"
    $Tag.Value = "Full"
} elseif ($Key -like "*DIFF*") {
    $Tag.Key = "BackupType"
    $Tag.Value = "Diff"
}

if ($Key) {
    try {
        [void](Write-S3ObjectTagSet -BucketName $Bucket -Key $Key -Tagging_TagSet $Tag)

    } catch {
        Throw $_
    }
}