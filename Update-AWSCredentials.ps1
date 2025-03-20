# Get Current Creds
$MyCreds = (Get-AWSCredential -ProfileName 'default').GetCredentials()

# Get the current IAM user for this profile
try {
    $myIamUser = Get-IAMUser
} catch {   
    Throw $_ 
}

# Retrieve the secret name from the IAM User Tags
if ($myIamUser.Tags.Count -eq 0) {
    Throw "SecretName tag not on user"
}
$Tags = $myIamUser.Tags
$secretName = $Tags[$tags.Keys.IndexOf("SecretName")].value

# Get the IAM Users Secret
$MySecretsAccessKeys = (Get-SECSecretValue -SecretId $secretName).SecretString | ConvertFrom-Json

# Check if new credential are in Secrets Manager
if ($MyCreds.AccessKey -ne $MySecretsAccessKeys.AccessKey) {
    # Update the local profile
    $profileLocation = "{0}\.aws\credentials" -f $home
    # Save new credentials to the .NET credential store
    Set-AWSCredential -AccessKey $MySecretsAccessKeys.AccessKey -SecretKey $MySecretsAccessKeys.SecretKey -StoreAs 'default'
    # Save the credential to the credential file.
    Set-AWSCredential -AccessKey $MySecretsAccessKeys.AccessKey -SecretKey $MySecretsAccessKeys.SecretKey -StoreAs 'default' -ProfileLocation $profileLocation
    #update the current credentials
    Set-AWSCredential -ProfileName 'default'    
    Write-Log -Message "Updated local profile from Secrets Manager"
}