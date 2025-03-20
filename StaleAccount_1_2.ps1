#Requires -Modules @{ModuleName = 'ConvertAdName'; ModuleVersion = '1.0.0.0'}
#Requires -Modules @{ModuleName = 'Microsoft.PowerShell.SecretManagement'; ModuleVersion='1.1.2'}
#Requires -Modules @{ModuleName = 'Microsoft.PowerShell.SecretStore'; ModuleVersion = '1.0.6'}
#Requires -Modules @{ModuleName = 'Microsoft.Graph.Beta.Users'; ModuleVersion = '2.15.0'}

#####################################################################################################################
#
# Author: Cliff Williams
# Version 1.2
#
# Required Modules: 
# * ConvertAdName
# * Microsoft.PowerShell.SecretManagement
# * Microsoft.PowerShell.SecretStore
#
# This scripts check OnPrem Active Directory for accounts that match the following Criteria.
# Enabled = true
# LastLogonDate < Today - $DisableTimeSpan (in days)
# PasswordLastSet < Today -$ RehireTimeSpan (in days)
# extensionAttribute6 = 'user'
#
# This script makes the following assumptions:
# 1. All AD User accounts associated with a "person" have extensionAttribute6 set to 'user'
# 2. That is a user account is rehired (enabled)) the service desk will have reset the password since the last script run ($RehireTimeSpan) when the account is enabled.
#    That either the Service Desk or the user will have logged in to either AD to Entra ID (Azure AD) before the next script run.
# 3. That the RehireTimeSpan parameter is set to the same interval (days) that the script runs.
#
# The AD Accounts found will be checked against the Entra ID (Azure AD) account.
# If the property SignInActivity.LastNonInteractiveSignInDateTime is newer than today - 129 days, do not process this user.
# 
# This script used the 'beta' profile of the Graph API in powershell.
# The SignInActivity property is not properly populated in the current graph profile.
# 
# We are storing the Access keys and certificate thumbprint in a local Secret store so we do not have these keys exposed as plain text. 
# This process uses the following modules:
# * Microsoft.PowerShell.SecretManagement
# * Microsoft.PowerShell.SecretStore
#
# To create the secret you must have a vault created and the store configuration setup properly.
# Configure the Store:
#
# Set-SecretStoreConfiguration -Authentication None -Scope CurrentUser -Interaction None.
#
# You will be prompted to create a password and then enter that password to set authentication to none.
# A password will not be required to retrieve the secret. This is necessary for an automated script.
#
# Create a vault:
#
# Register-Vault -Name 'default' -ModuleName Microsoft.Powershell.SecretStore -DefaultVault -AllowClobber
#
# If you create more than one vault SecretStore will save secrets in all vaults. This is by design. So only create one vault.
# Vaults can only be created in the current user scope, so you will have to log in as the user running the script to create the vault.
#
# Create and save the Secret
# $SecretIn = @{
#   ClientId = 'xxxxxxxxxxxxxxxxxxxxxx'
#   TenantId = 'xxxxxxxxxxxxxxxxxxxxxx'
#   CertificateThumbprint = 'XXXXXXXXXXXXXXXXXXXXXX'
# }
# $Secret = $SecretIn | ConvertTo-Json
# Set-Secret -Name 'ExoAppId' -Secret $Secret
#########################################################################################################################

Param (
    [Parameter(Mandatory)]
    [string]$SearchBase,
    [Parameter(Mandatory)]
    [int]$DisableTimeSpan,
    [Parameter(Mandatory)]
    [int]$RehireTimeSpan,
    [switch]$ReportOnly,
    [string]$MoveTo,
    [string]$Recipients
)

# We need to set an alias as we are using the Beta module for MS Graph (Yeah, Graph is frustrating!)
# This way whjen these features become standard we can change the '#requires' statement above and remove this alias.

Set-Alias -Name Get-MgUser -Value Get-MgBetaUser

$CurrentDate = Get-Date


$LogName = "$PSScriptRoot/StaleAccounts_{0}.log" -f ($CurrentDate.ToString("yyyyMMdd_mmss"))

Start-Transcript -Path $LogName 

# Get the Domain we are running under. Balfour US has 2 domains.
# This script is run separately in each domain.
$Domain = (Get-ADDomain).DnsRoot
$ReportFileName = "$PSScriptRoot/{0}_StaleAccounts.csv" -f $Domain

# If SearchBase is provided in Conanical format, convert it to DN format.
If ($SearchBase.Contains('/') -or $SearchBase.Contains('.') ) {
    # If the $SearchBase is provided in Conanical format at the root of the domain, 
    # i.e. bbc.local we must append a / to the string or Convert-ADName will throw an error.
    If ($SearchBase.Contains('.') -and (-not $SearchBase.Contains('/')) ) {
        $SearchBase += "/"
    }
    $SearchBase = Convert-ADName -UserName $SearchBase -OutputType DN
}

$RunDate = $CurrentDate.ToShortDateString()

$endDate = $CurrentDate.AddDays($DisableTimeSpan * -1)

$RehireDate = $CurrentDate.AddDays($RehireTimeSpan * -1)

$Filter = {Enabled -eq $true -and LastLogonDate -lt $endDate -and PasswordLastSet -lt $RehireDate -and extensionAttribute6 -eq 'user'}

$Params =@{
    Properties = @('LastLogonDate', 'Enabled', 'extensionAttribute6', 'CanonicalName')
    SearchBase = $SearchBase
    SearchScope = 'Subtree'
    Filter = $Filter
}

$StaleAccounts = Get-ADUser @Params

# Log the number of potential stale accounts found to the transcript log.
Write-Host "Matching AD Accounts found: $($StaleAccounts.Count)"

###########################################################################
# Check EntraID (Azure AD) Accounts associated with the stale users.      #
###########################################################################

# Connect to MS Graph

# Get the App ID connection info from a local secret store
$ExoAppIds = Get-Secret -Name 'ExoAppId' -AsPlainText | ConvertFrom-Json

# Connect to MS Graph
Try {
    Connect-MgGraph -AppId $ExoAppIds.ClientId -TenantId $ExoAppIDs.TenantId -CertificateThumbprint $ExoAppIds.CertificateThumbprint    
    #Select-MgProfile -Name 'beta'
} catch {
    Write-Error $_
    Stop-Transcript
    exit 1
}

# Loop through the Stale Users and verify cloud sign on.
# We return each process user on the pipeline so we get the updated information and exclude 
# any accounts that were not processed.
Foreach ($StaleAccount in $StaleAccounts) {
    # Get the Entra ID user ID if the account.
    # We need this because Graph will only return requested properties if the UserId is provided in GUID format
    # (Yeah, Graph is weird!)

    Write-Host "Processing AD User: $($StaleAccount.Name)"
    $UserLastSignInDateTime = $null

    $UserId = (Get-MgUser -UserId $StaleAccount.UserPrincipalName -ErrorAction SilentlyContinue).Id 
    If ($UserId) {        
        
        # Get the user including SignInActivity
        $User = Get-MgUser -UserId $UserId -Property SignInActivity

        # Check if LastSuccessful Sign In date is newer than 120 days
        # There are several dates in the SignINActivity object We have determined that AdditionalProperties.LastSuccessfulSignInDateTime is the most accurate.
        try {
            $UserLastSignInDateTime = $User.SignInActivity.lastSuccessfulSignInDateTime
        } catch {
            $UserLastSignInDateTime = $null
        }
    
        If ($UserLastSignInDateTime -gt $endDate) {
            # The user has signed into the cloud in the last 120 days.
            # Step out of the loop and do not process this user.
            Write-Host "AD user $($StaleAccount.Name) Signed into Microsoft 365 on $UserLastSignInDateTime, account is not stale"
            Continue
        }
    }

    If (-not $ReportOnly) {
        # Disable the account
        try {
            $StaleAccount | Disable-ADAccount
            # Prepend a message to the Description property
            $ParentContainer = $StaleAccount.CanonicalName.Substring(0,$StaleAccount.CanonicalName.LastIndexOf('/'))            
            $NewDescription = "Stale Account: Moved from {0}, Moved On: {1} | {2}" -f $ParentContainer, $RunDate, ($StaleAccount.Description)
            $StaleAccount | Set-ADUser -Description $NewDescription
            
            Write-Host "Disabled AD Account $($StaleAccount.Name)"
        } catch {
            Write-Error $_.ErrorDetails
        }

        # Move the account
        if ($MoveTo.Contains('/')) {
            $MoveTo = Convert-ADName -UserName $MoveTo -OutputType DN
        }
        # Verify the MoveTo OU exists
        if (-not (Get-ADOrganizationalUnit -Identity $MoveTo)) {
            Write-Error "MoveTo Organizational Unit does not exist"
            Stop-Transcript
            exit 1
        }
        try {
            $StaleAccount | Move-ADObject -TargetPath $MoveTo
            Write-Host "Moved AD Account $($StaleAccouunt.Name) from $ParentContainer to $MoveTo"
        } catch {
            Write-Error $_.ErrorDetails
        }

        # Retrieve the updated AD Account. We do this so that the Enabled property shows the account is disabled.
        # We must specify SamAccountName because the DN of the account has changed due to being moved.
        $StaleAccount = $StaleAccount.SamAccountName | Get-ADUser -Properties 'LastLogonDate', 'Enabled', 'extensionAttribute6'
        $StaleAccount | Add-Member -MemberType NoteProperty -Name 'CloudLastLogonDate' -Value $UserLastSignInDateTime -Force
        $StaleAccount | Add-Member -MemberType NoteProperty -Name 'ParentContainer' -Value $ParentContainer -Force

        #Write the updated Account to the pipeline so it updates $ProcessedAccounts
        # Write-Output $StaleAccount
    }
}

# Export the Processed Accounts
$StaleAccounts | Select-Object Name, SamAccountName, LastLogonDate, CloudLastLogonDate, `
    @{Name = 'MovedFrom';Expression={$_.ParentContainer}}, `
    @{Name = 'MoveDate';Expression={$RunDate}}, `
    @{Name="MovedTo";Expression={$MoveTo}} | Export-Csv -Path $ReportFileName -NoTypeInformation

# Only send the report if Recipients are provided.
if ($Recipients) {
    # Retrieve the AWS SES credentials from AWS Secrets Manager.
    # You must either be running this script on an AWS Instance with an Instance role
    # that has permissions to retrieve the secret or under a user profile that has.
    # configured AWS Access Keys assigned to an IAM user with permissions to retrieve the secret.
    # If you are using any other method to send mail, modify this section appropriately.

    $EmailRecipients = $Recipients.Split(",")

    $smtpCreds = (Get-SECSecretValue -SecretId 'SES_SMTP_User').SecretString | ConvertFrom-Json
    $pw = ConvertTo-SecureString -String $smtpCreds.SmtpPassword -AsPlainText -Force
    $creds = [PSCredential]::New($smtpCreds.SmtpUsername, $pw)

    $Params = @{
        SMtpServer  = $smtpCreds.SmtpHost
        Port        = $smtpCreds.SmtpPort
        From        = 'StaleAccountReport@balfourbeattyus.com'
        To          = $EmailRecipients
        Subject     = "Stale user report for $Domain"
        body       = "Attached is the stale user account for $Domain"
        Attachments = $ReportFileName
        Credential  = $creds
        UseSSL      = $true
    }
    Send-MailMessage @Params -WarningAction:SilentlyContinue
}
Stop-Transcript