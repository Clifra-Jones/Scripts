# update SQL Mail with new credentials from Secrets Manager
# script must run under an account that has db_reader, db_writer and execute permissions to the msdb database.

Param(
    [string]$sqlserver
)

if (-not $sqlserver) {
    $sqlserver = 'localhost'
}

# Script Variables
$dateCode = Get-Date -Format "MMddyyyy_HHmm"
$logPath = "$PSScriptRoot\logs\Update-SQLMailCreds"
if (-not (Test-Path -Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath | Out-Null
}
$logFile = "$LogPath\Update-SQLMailCreds_$dateCode.log"
if (-not (Test-Path -Path $logFile)) {
    New-Item -Path $logFile | Out-Null
}

#Logging function
function Write-Log($Message) {
    $DateTime = get-date -Format "yyyy-MM-dd HH:mm"
    $msg = "{0} -- {1}" -f $DateTime, $Message
    Add-Content -Path $logFile -Value $Msg
}

# First check to see if the IAM Account running this script has a new access Key pair.
# Get Current Creds
$MyCreds = (Get-AWSCredential -ProfileName 'default').GetCredentials()

$myIamUser = Get-IAMUser
if ($myIamUser.Tags.Count -eq 0) {
    $Msg = "No tags set on IAMUser {0}." -f $myIamUser.UserName
    Write-Log $Msg
    Throw $Msg
}
$Tags = $myIamUser.Tags
if ($Tags.Key.IndexOf("SecretName") -eq -1) {
    $msg = "SecretName tag not found on IAMUser {0}" -f $myIamUser.UserName
    Write-Log $Msg
    Throw $Msg
}
$secretName = $Tags[$tags.Key.IndexOf("SecretName")].value

Try {
    $MySecretsAccessKeys = (Get-SECSecretValue -SecretId $secretName).SecretString | ConvertFrom-Json
} catch {
    Write-Log $_.Exception.Message
    Throw $_
}

# Check if new credential are in Secrets Manager
if ($MyCreds.AccessKey -ne $MySecretsAccessKeys.AccessKeyId) {
    #Update the local profile
    $profileLocation = "{0}\.aws\credentials" -f $home
    Set-AWSCredential -AccessKey $MySecretsAccessKeys.AccessKeyId -SecretKey $MySecretsAccessKeys.SecretAccessKey -StoreAs 'default' -ProfileLocation $profileLocation
    Set-AWSCredential -AccessKey $MySecretsAccessKeys.AccessKeyId -SecretKey $MySecretsAccessKeys.SecretAccessKey -StoreAs 'default'
    # Update the current credentials
    Set-AWSCredential -ProfileName 'default'    
    Write-Log -Message "Updated default local profile from Secrets Manager"
}

# Retrieve the secret for the the SES User
$ses_creds = (Get-SECSecretValue -SecretId "SES_SMTP_User").SecretString | ConvertFrom-Json

# This SQL script retrieves the current SQL Database Mail configurations
$sqlGetDbMailAccounts = "SELECT [sysmail_server].[account_id]
,[sysmail_account].[name] AS [AccountName]
,[servertype]
,[servername] AS [SMTPServerAddress]
,[Port]
,[Username]

FROM [msdb].[dbo].[sysmail_server]
INNER JOIN [msdb].[dbo].[sysmail_account]
ON [sysmail_server].[account_id]=[sysmail_account].[account_id]"

# this SQL script updates the Database Mail account for the Account Id.
$sqlUpdateDbMailAccount = "EXEC [dbo].[sysmail_update_account_sp] 
     @account_id='{0}'
    ,@username='{1}'
    ,@password='{2}'"

# Retrieve the Database Mail Accounts
$dbMailAccounts = Invoke-Sqlcmd -ServerInstance $sqlserver -Database msdb -Query $sqlGetDbMailAccounts

# Loop through each account and check if the username has changed.
# if the username has changed update the Database Mail configuration.
foreach ($dbMailAccount in $dbMailAccounts) {
    If ($dbMailAccount.Username -ne $ses_creds.SmtpUsername) {
        try{
            $Procedure = $sqlUpdateDbMailAccount -f $dbMailAccount.account_Id, $ses_creds.SmtpUsername, $ses_creds.SmtpPassword
            $result = Invoke-Sqlcmd -ServerInstance $sqlserver -Database 'msdb' -Query $Procedure
        } catch {
            Write-Log $result
            throw $result
        }
        $msg = "Database mail account {0} updated to new credentials." -f $dbMailAccount.AccountName
        Write-Log $msg
    }
}