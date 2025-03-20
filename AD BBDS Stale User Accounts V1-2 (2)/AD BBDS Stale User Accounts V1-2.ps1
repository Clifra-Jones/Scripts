# This script disables on-prem accounts that are not in use.  it checks the onprem lastLogonDate, the Azure AD lastLogonDate, and the EXO lastUserActionTime against a threshold value.
# First it gets a list of account from on-premises AD, which have not been logged onto for other a threshold number of days.
# Then it adds the last logon date from Azure AD, if the account is synchronised there, and also the lastUserActionTime from EXO, if the account has a mailbox.
# If all three dates are older than the threshold, the account is disabled.
# An exceptions list is implemented.
# Another threshold is used to protect accounts that have never been logged onto because they are newly set up.
# EXO last logon info is obtained by a separate script, due to an incompatability between the MS MG and EXO V3 CMDLets.

# V1.2 adds the following over V1.1
# The threshold that prevents newly created accounts from being disabled before first use, $newAccountThreshold, now takes into account accounts that have been re-enabled, as well as new accounts. 
# This is done by looking at the modified date of the UserAccountControl attribute on the account.
# We have a lot of users who rejoin, and re-use their own accounts, so this should prevent accidental disabling.

#########################################################################
# Functions

# Connects to MGGraph using an application and certificate.  The private key of the certificate must be available to the account running the script.
# EXAMPLE USAGE # Connect-ToMicrsoftGraph -tenantID "a04222fe-0c5c-40bb-8420-97a219ba514e" -applicationID "6e8d74a4-09ca-4dbf-bf36-b3f59e95629f" -certificateThumbprint "325cf55c7ea46363a2c5b60f64f8a8328cc32123" -profileName "Beta"
# Checks connection and exits the script completely if a connection cannot be made.  If addressing multiple tenants, you might want to change this and use the continue command to go on to the next tenant.
Function Connect-ToMicrsoftGraph {
    Param (
        [Parameter(Mandatory=$true)]
        [string]$tenantID,
        [string]$applicationID,
        [string]$certificateThumbprint,
        [string]$profileName # "v1.0" is the default and can be specified in this paramter, but doesn't include lastLogonDate, etc.  "Beta" is probably the one to use for now.
        # NOTE - Scopes are not needed when connecting with an application that has application permissions (not delegated) assigned.
    )

    DisConnect-MgGraph -ea SilentlyContinue # This function is likely to be called from a foreach loop, so running a disconnect seems prudent.
    Connect-MgGraph -ClientID $applicationID -TenantId $tenantID -CertificateThumbprint $certificateThumbprint -ea Continue
    Select-MgProfile -Name $profileName -ea Stop
    $mgcontext = Get-MgContext
        
    If ($mgcontext) {
        Write-Host "Connected to MGGraph"
        RETURN $mgcontext
    }
    Else {
        Write-Error "Error connecting to tenant $tenantID using application $applicationID and certificate $certificateThumbprint.  ProfileName was $profileName"
    }
}

# Useage: $EXOMailboxes = get-EXOMailboxInfo -AppID "xxxxxxxxxxxxxxxxxx" -CertificateThumbprint "xxxxxxxxxxxxxxxxxxxxxxxxxx" -Organization "balfourbeatty.onmicrosoft.com" -RequestDateTime $dateTimeString
# Returns all mailboxes, with lastUserActionTime added as a member
Function get-EXOMailboxInfo {
    Param (
        $AppID,
        $CertificateThumbprint,
        $Organization,
        $RequestDateTime,
        $EXOConsistancyThreshold # Script will look for existing EXO export to save time.  Use this threshold to set how far back you are willing to go (in hours)
    )
    
    $EXOScriptPath = "\\automationserver\c$\Automation\_EXOMailboxInfo"
    
    $existingEXOExport = get-ChildItem "$EXOScriptPath\Logs" | where-object {$_.Name -like "* EXO MailboxObjects.csv" -and $_.LastWriteTime -gt (get-Date).AddHours(-$EXOConsistancyThreshold)} | sort-object -Descending LastWriteTime | select-object -first 1

    If ($existingEXOExport) {
        Write-Host "Previous export found $($existingEXOExport.FullName)"
        $EXOMailboxes = import-csv $existingEXOExport.FullName
    }
    Else {
        $result = pwsh.exe -Noprofile -WindowStyle Hidden -ExecutionPolicy Bypass -file "$EXOScriptPath\ExportEXOInfo V2-0.ps1" -AppID $AppID -CertificateThumbprint $CertificateThumbprint -Organization $Organization -RequestDateTime $RequestDateTime
        $result
        $EXOMailboxes = import-csv "$EXOScriptPath\Logs\$RequestDateTime EXO MailboxObjects.csv"
    }

    If ($EXOMailboxes) {
        ForEach ($EXOMailbox in $EXOMailboxes) {
            If ($EXOMailbox.LastUserActionTime) {
                $EXOMailbox | Add-member -MemberType NoteProperty -Name LastUserActionTimeString -Value $EXOMailbox.LastUserActionTime -Force
                $EXOMailbox.LastUserActionTime = Get-Date $EXOMailbox.LastUserActionTime
            }
            else {
                $EXOMailbox | Add-member -MemberType NoteProperty -Name LastUserActionTimeString -Value $null -Force
                $EXOMailbox.LastUserActionTime = $null
            }
        }
        Return $EXOMailboxes
    }
    Else {
        Write-Error "Error returning mailbox info"
    }
}

# Disables account and sets new description with "Unused Disabled" prefix
Function Disable-UserAccount {
    Param ($ADUserobject,$scriptMode)
    
    If ($scriptMode -eq "DisableAccounts") {
        Try { 
            disable-ADAccount $ADUserobject.distinguishedName -ea stop
            $DisabledDescription = "Unused Disabled: $((get-date).ToString("ddMMyyyy")) $($ADUserobject.description)"
            Set-ADUser -Identity $ADUserobject.distinguishedName -Description $DisabledDescription -ea stop
        }
        Catch {
            Write-Error "Error disabling user $($ADUserobject.distinguishedName)"
        }
    }
    else {
        Return "Reporting only mode - disabling $($ADUserobject.distinguishedName)"
    }
}

# Usage: Exit-Script $LogAndTranscriptRetentionPeriod
Function Exit-Script {
    Param(
        $LogAndTranscriptRetentionPeriod
    )
    
    # Clean up and finish
    $OldLogs = get-ChildItem "$($scriptPath)\Logs" | Where-Object {$_.LastWriteTime -lt ((get-Date).AddDays(-$LogAndTranscriptRetentionPeriod))}
    $OldLogs | ForEach-Object {remove-Item -Path $_.FullName  -Force -Confirm:$False}
    $OldTranscripts = get-ChildItem "$($scriptPath)\Transcripts" | Where-Object {$_.LastWriteTime -lt ((get-Date).AddDays(-$LogAndTranscriptRetentionPeriod))}
    $OldTranscripts | ForEach-Object {remove-Item -Path $_.FullName  -Force -Confirm:$False}

    Stop-Transcript
    EXIT
}

#########################################################################
# Script set up

$scriptPath = split-Path ($MyInvocation.MyCommand.Path) -parent # NOTE - this only works when executing the whole script, not a code selection.
$scriptName = (split-Path ($MyInvocation.MyCommand.Path) -Leaf).Replace(".ps1","") # NOTE - this only works when executing the whole script, not a code selection.
$dateTimeString = (get-date).ToString("dd-MM-yyyy HH-mm")
$LogAndTranscriptRetentionPeriod = 30 # In days
Start-Transcript -Path "$scriptPath\transcripts\$dateTimeString $scriptName.txt"

#########################################################################
# Sript body

$scriptMode = "DisableAccounts" # Script actions only completed if this is set to "DisableAccounts".  Set to anything else to put in reporting only mode.
$staleAccountThreshold = (get-Date).AddDays(-60) # Accounts with no activity for longer than this number of days will be considered stale
$newAccountThreshold = (get-Date).AddDays(-21) # Accounts created within this number of days will be ignored
$namedExceptions = import-csv "$scriptPath\InputFiles\namedExceptions.csv"
$certificateThumbprint = "xxxxxxxxxxxxxxxx"
$EXOConsistancyThreshold = 3 # Exchange info is exported every 3 hours from 00:00:00 every day, so setting this to 3 means this script will never have to initiate a new export

# Get mailboxes info
Try {
    $EXOMailboxes = get-EXOMailboxInfo -AppID "xxxxxxxxxxxxxxxxxxxxxxxxxxxx" -CertificateThumbprint $certificateThumbprint -Organization "balfourbeatty.onmicrosoft.com" -RequestDateTime $dateTimeString -EXOConsistancyThreshold $EXOConsistancyThreshold -ea Stop
}
Catch {
    Write-error "Error retrieving mailbox info"
    Exit-Script $LogAndTranscriptRetentionPeriod
}
Write-Host "Mailboxes found $($EXOMailboxes.Count)"

# Build hashtable of mailboxes for lookup speed
$EXOMailboxesHT = @{}
ForEach ($EXOMailbox  in $EXOMailboxes) {
    $EXOMailboxesHT.Add($EXOMailbox.ExternalDirectoryObjectId,$EXOMailbox.LastUserActionTime)
}

# Get on-prem accounts
Try {
    $AgedOnPremAccounts = Get-ADUser -Filter {(enabled -eq $True -and PasswordNeverExpires -eq $False -and WhenCreated -lt $newAccountThreshold -and samAccountType -eq "805306368") -and (LastLogonDate -lt $staleAccountThreshold -or (LastLogonDate -notlike "*"))} -properties lastLogonDate,whenCreated,passWordLastSet,whenChanged,mailNickName,description,userPrincipalName -ea Stop
}
catch {
    Write-error "Error getting on-prem accounts"
    Exit-Script $LogAndTranscriptRetentionPeriod
}
Write-Host "On-prem stale accounts found: $($AgedOnPremAccounts.Count)"


# Get Azure AD accounts
try {
    Connect-ToMicrsoftGraph -tenantID "xxxxxxxxxxxxxxxxxxx" -applicationID "xxxxxxxxxxxxxxxxx" -certificateThumbprint $certificateThumbprint -profileName "Beta" -ea Stop
}
catch {
    Write-error "Error connecting to MG"
    Exit-Script $LogAndTranscriptRetentionPeriod
}

try {
    $AllAzureADAccounts = get-MGUser -Filter "accountEnabled eq true and UserType eq 'Member'" -all -Property SignInActivity -ea Stop
}
catch {
    Write-error "Error getting Azure AD accounts"
    Exit-Script $LogAndTranscriptRetentionPeriod
}
Write-host "Azure AD Accounts found: $($AllAzureADAccounts.Count)"

# Filter all but synced accounts
$AllAzureADAccounts = $AllAzureADAccounts | Where-object {$_.OnPremisesDistinguishedName -ne $null}
Write-host "Synced Azure AD Accounts found: $($AllAzureADAccounts.Count)"

# Build hashtable of Azure AD accounts and last signin dates for lookup speed
$AllAzureADAccountsHT = @{}
ForEach ($AllAzureADAccount  in $AllAzureADAccounts) {
    $AllAzureADAccountsHT.Add($AllAzureADAccount.OnPremisesDistinguishedName,$AllAzureADAccount)
}

# Go through each onprem account and add the Azure AD/EXO info, work out what's stale
ForEach ($AgedOnPremAccount in $AgedOnPremAccounts) {
    # Identify exceptions from the namedExceptions file
    $namedException = $namedExceptions | where-Object {$_.SamAccountName -eq $AgedOnPremAccount.SamAccountName}
    If ($namedException) {
        $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name Exception -Value $true -Force
        $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name ExceptionReason -Value $namedException.Reason -Force
    }
    else {
        $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name Exception -Value $false -Force
        $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name ExceptionReason -Value $null -Force
    }
    
    # New in V1.2 - Identify accounts that have been re-enabled within the $newAccountThreshold time (to prevent accounts that have been re-enabled being disabled again before first use)
    # There is a strange issue on a small number of accounts (21 at testing), which I couldn't get the objectMeta for.  Something about an invalid character, which I couldn't solve.
    # As it was a small number, I have silenced the error with a Try Catch block.
    Try {$UACAttribute = Get-ADReplicationAttributeMetadata $AgedOnPremAccount.ObjectGUID -Server ($env:LogonServer).Replace("\\","") -ea Stop | Where-Object { $_.attributename -eq "userAccountControl" }} Catch {$UACAttribute = $null}

    If ($UACAttribute -and $UACAttribute.LastOriginatingChangeTime -gt $newAccountThreshold) {
        $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name  'AccountReenabled' -Value $True -Force
    }
    Else {
        $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name  'AccountReenabled' -Value $False -Force
    }

    # Add Azure AD LastSigninDateTime to on-prem user object
    $AzureADLastSigninDateTime = ($AllAzureADAccountsHT.($AgedOnPremAccount.distinguishedName)).SignInActivity.LastSignInDateTime
    If ($AzureADLastSigninDateTime) {$AzureADLastSigninDateTimeString = (get-Date $AzureADLastSigninDateTime).ToString("dd/MM/yyyy HH:mm")} Else {$AzureADLastSigninDateTimeString = $null}

    $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name  AzureADLastSigninDateTime -Value $AzureADLastSigninDateTime -Force
    $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name  AzureADLastSigninDateTimeString -Value $AzureADLastSigninDateTimeString -Force
    $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name  AzureADObjectID -Value ($AllAzureADAccountsHT.($AgedOnPremAccount.distinguishedName)).Id -Force
    
    # Add EXO lastUserActionTime
    Try {$EXOLastUserActionTime = $EXOMailboxesHT.($AgedOnPremAccount.AzureADObjectID)} Catch {$EXOLastUserActionTime = $null}
    If ($EXOLastUserActionTime) {$EXOLastUserActionTimeString = (Get-Date $EXOLastUserActionTime).ToString("dd/MM/yyyy HH:mm")} Else {$EXOLastUserActionTimeString = $null}
    
    $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name  EXOLastUserActionTime -Value $EXOLastUserActionTime -Force
    $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name  EXOLastUserActionTimeString -Value $EXOLastUserActionTimeString -Force

    # Modified for V1.2 - Apply some logic and an account status property to the on-prem user object, including newAccountThreshold for re-enabled users,
    If ($AgedOnPremAccount.EXOLastUserActionTime -lt $staleAccountThreshold -and $AgedOnPremAccount.AzureADLastSigninDateTime -lt $staleAccountThreshold -and $AgedOnPremAccount.AccountReenabled -eq $False) {
        # Mark account as stale
        $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name AccountStatus -Value "Stale" -Force
    }
    else {
        # Mark account as in use
        $AgedOnPremAccount | Add-Member -MemberType NoteProperty -Name AccountStatus -Value "InUse" -Force
    }
}

$AgedOnPremAccounts | export-csv "$ScriptPath\Logs\$dateTimeString All On-Prem Stale Accounts.csv" -noType

$AccountsToDisable = $AgedOnPremAccounts | where-object {$_.AccountStatus -eq "Stale" -and $_.Exception -eq $False}

Write-Host "Accounts to disable: $($AccountsToDisable.Count)"
$AccountsToDisable | export-csv "$ScriptPath\Logs\$dateTimeString Disabled Accounts.csv" -noType

ForEach ($AccountToDisable in $AccountsToDisable) {
    Disable-UserAccount $AccountToDisable $scriptMode
}

# Remove Unused Disabled prefixes from descriptions of accounts that have been re-enabled.
$EnabledUsersWithPrefix = get-ADUser -Filter {description -like "Unused disabled: *" -and enabled -eq $True} -Properties description

If ($EnabledUsersWithPrefix -and $scriptMode -eq "DisableAccounts") {
    ForEach ($EnabledUserWithPrefix in $EnabledUsersWithPrefix) {
        $description = $EnabledUserWithPrefix.description -replace "Unused disabled: \d{8} ", ""
        $description = $description.TrimStart()
        $description = $description.TrimEnd()
        
        If ($description) {
            Set-ADUser $EnabledUserWithPrefix.samAccountName -description $description.ToString() # -whatif
        }
        Else {
            Set-ADUser $EnabledUserWithPrefix.samAccountName -Description $null # -WhatIf
        }
    }
}

Exit-Script $LogAndTranscriptRetentionPeriod