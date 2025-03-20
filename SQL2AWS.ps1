# Script to upload SQL backups to AWS S3
Param (
    [string]$BackupLocation,
    [string]$S3Bucket,
    [string]$serverName
)

# First check to see if the IAM Account running this script has a new access Key pair.
# Get Current Creds
$MyCreds = (Get-AWSCredential -ProfileName 'default').GetCredentials()

try {
    $myIamUser = Get-IAMUser
} catch {   
    Throw $_ 
}
if ($myIamUser.Tags.Count -eq 0) {
    Throw "SecretName tag not on user"
}
$Tags = $myIamUser.Tags
$secretName = $Tags[$tags.Keys.IndexOf("SecretName")].value

$MySecretsAccessKeys = (Get-SECSecretValue -SecretId $secretName).SecretString | ConvertFrom-Json

#Check if new credential are in Secrets Manager
if ($MyCreds.AccessKey -ne $MySecretsAccessKeys.AccessKey) {
    #Update the local profile
    $profileLocation = "{0}\.aws\credentials" -f $home
    Set-AWSCredential -AccessKey $MySecretsAccessKeys.AccessKey -SecretKey $MySecretsAccessKeys.SecretKey -StoreAs 'default' -ProfileLocation $profileLocation
    #update the current credentials
    Set-AWSCredential -ProfileName 'default'    
    Write-Log -Message "Updated local profile from Secrets Manager"
}

Invoke-Expression "aws s3 sync $BackupLocation s3://$S3Bucket/$serverName"