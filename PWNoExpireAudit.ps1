using namespace System.Collections.Generic
$ADUsers = Get-ADUser -properties * -Filter {PasswordNeverExpires -eq $true -and Name -notlike "HealthMailbox*" -and Enabled -eq $true } | Select-Object Name, SamAccountName, UserPrincipalName, Description, CanonicalName
$ServiceAccounts = List::New()

foreach ($ADUser in $ADUsers) {
    if ($ADUser.msExchRecipientTypeDetails) {
        $RecipientTypeDetails = (Get-Mailbox $ADUsers.UserPrincipalName).$RecipientTypeDetails        
    }
}
