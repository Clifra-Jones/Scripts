# MOnthly O365 AUdit
#
# Author: Cliff Williams
# Revised: 3/9/2020
#
Param (
    $DisabledUserOutFile = 'Disabled_AD_Accounts.csv',
    $LicensedSharedMailboxesOutFile = 'LicensedSharedMailboxes.csv'
)


Import-Module ExchangeOnlineManagement 
Connect-ExchangeOnline 
Connect-MsolService

#$Recipients = "cwilliams@bbus.com,gkastanis@balfourbeattyus.com"
$Recipients = "cwilliams@bbus.com"

if (Test-Path -Path $DisabledUserOutFile) {
    Remove-Item $DisabledUserOutFile
}
If (Test-Path -Path $LicensedSharedMailboxesOutFile) {
    Remove-Item $LicensedSharedMailboxesOutFile
}

"Gathering Disabled AD Accounts"
#$Disabled_AD_Accounts = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox | `
#    Get-MsolUser | Where-Object {$_.Blockcredential -eq "True"}

$Mailboxes = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails UserMailbox
$Disabled_AD_Accounts = New-Object System.Collections.Generic.List[psobject]
$i = 0
foreach ($Mailbox in $Mailboxes) {
    $MSOLUser = Get-MsolUser -UserPrincipalName $mailbox.UserPrincipalName
    $i += 1
    Write-Progress -Activity "Checking User" -Status "User:$($MSOLUser.UserPrincipalName)" -PercentComplete ($i/$mailboxes.Count*100)    
    If ($MsolUser.BlockCredential -eq $true) {
        $DisabledUser = [pscustomobject][ordered]@{
            UserPrincipalName = $MSOLUser.UserPrincipalName
            DisplayName = $MSOLUser.DisplayName
            IsLicensed = $MSOLUser.IsLicensed
            BlockCredential = $MSOLUser.BlockCredential
            PasswordNeverExpires = $MSOLUser.PasswordNeverExpires
        }
        #$DisabledUser = New-Object -TypeName psobject -Property $Props
        $Disabled_AD_Accounts.Add($DisabledUser)
    }
}

"Gathering Shared Mailbox"
#$Licensed_Shared_Mailboxes = Get-EXOMailbox -ResultSize unlimited -RecipientTypeDetails SharedMailbox | `
#    Get-MsolUser | Where-Object {$_.isLicensed -eq "True"}
$Mailboxes = Get-EXOMailbox -ResultSize Unlimited -RecipientTypeDetails SharedMailbox
$Licensed_Shared_Mailboxes = New-Object System.Collections.Generic.List[psobject]
$i = 0
foreach ($Mailbox in $Mailboxes) {
    $MSOLUser = Get-MsolUser -UserPrincipalName $mailbox.UserPrincipalName
    $i += 1
    Write-Progress -Activity "Checking User" -Status "User:$($MSOLUser.UserPrincipalName)" -PercentComplete ($i/$mailboxes.Count*100)
    if ($MSOLUser.IsLicensed -eq $true) {
        $Shared_Mailbox = [PSCustomObject][ordered]@{
            UserPrincipalName = $MSOLUser.UserPrincipalName
            DisplayName = $MSOLUser.DisplayName
            IsLicensed = $MSOLUser.IsLicensed
            BlockCredential = $MSOLUser.BlockCredential
            PasswordNeverExpires = $MSOLUser.PasswordNeverExpires
        }
        $Licensed_Shared_Mailboxes.Add($Shared_Mailbox)
    }
}

$Disabled_AD_Accounts.ToArray() | Export-Csv $DisabledUserOutFile -NoTypeInformation
$Licensed_Shared_Mailboxes.ToArray() | Export-Csv $LicensedSharedMailboxesOutFile -NoTypeInformation

$Attachments = @()
$Attachments += $DisabledUserOutFile
$Attachments += $LicensedSharedMailboxesOutFile

$Attachments | Send-MailMessage -SmtpServer '172.16.0.7' -To $Recipients -From 'cwilliams@balfourbeattyus.com' -Subject 'O365 MOnthly Audit' `
    -Body "Here is the monthly o365 Audit."

    