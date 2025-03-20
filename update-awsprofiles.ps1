# This script updates AWS Profiles with access Keys stored in Secrets Manager

# ARN String for secrets manager
$secretARN = "arn:aws:secretsmanager:us-east-1:268928949034:secret:{0}"

# Get a list of local profiles
$profileNames = (Get-AWSCredential -ListProfileDetail).ProfileName

# Loop through the profiles and retrieve the access keys and update as necessary

foreach ($profileName in $profileNames) {
    # Get Profile credentials
    $creds = (Get-AWSCredential -ProfileName $profileName).GetCredentials()
    # Set the default credentials
    Set-AWSCredential -AccessKey $creds.AccessKey -SecretKey $creds.SecretKey
    # Get the IAM User for these credentials
    Try {
        $iamUser = Get-IAMUser 
    } catch {
        Write-Host "The credential for profile $profileName are invalid!" -ForegroundColor Red
        Continue
    }
    # Get the SecretName
    if ($iamUser.Tags.Count -gt 0) {
        $Tags = $iamUser.Tags
        $SecretName = $Tags[$Tags.Key.indexOf("SecretName")].Value
        if (-not $SecretName) { Continue }
        $SecretNameArn = $SecretARN -f $SecretName
    } else {
        Continue
    }
    # Get the secret values
    try {
        $SecretValues = (Get-SECSecretValue -SecretId $SecretNameArn).SecretString | ConvertFrom-Json
    } catch {
        Write-Host $_.Exception.Message -ForegroundColor Red
        Continue 
    }
    # Update the local profile if new
    if ($creds.AccessKey -ne $SecretValues.AccessKeyId) {
        Set-AWSCredential -AccessKey $SecretValues.AccessKeyId -SecretKey $SecretValues.SecretAccessKey -StoreAs $profileName
        Write-Host "Profile $profileName updated!"
    }
}