# Default parameters
$PSDefaultParameterValues.Add("Invoke-Sqlcmd:Encrypt", "Optional")

#Set-PSReadLineOption -EditMode Windows
# function prompt {
#     if ((Get-Location).Path.Length -gt 30) {
#         $first, $second, $third, $folder = (Get-Location).Path -split "(?<=\/)"
#         $p = $first
#         if ($second) {
#             if (($p + $second).Length -gt 30) {
#                 $p += ".../"
#             } else {
#                 $p += $second
#             }   
#         }
#         if ($third) {
#             if (($p + $third -gt 30)) {
#                 $p += ".../"
#             } else {
#                 $p += $third
#             }
#         }
#         if ($folder) {
#             $p += ".../" + $folder[-1]
#         }        
#     } else {
#         $p = (Get-Location).Path
#     }
#     "PS $p>"
# }

# First check to see if the IAM Account running this script has a new access Key pair.
# Get Current Creds
## ARN String for secrets manager
$secretARN = "arn:aws:secretsmanager:us-east-1:268928949034:secret:{0}"
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
    Write-Host -Message "Updated default AWS credentials profile from Secrets Manager" -ForegroundColor Yellow
}