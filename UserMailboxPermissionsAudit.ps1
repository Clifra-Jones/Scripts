#Requires -Modules @{ModuleName = "ExchangeOnlineManagement"; ModuleVersion = "3.0.0"}
#Requires -Modules @{ModuleName = "Microsoft.Graph.Users"; ModuleVersion = "2.21.1"}
#Requires -Modules @{ModuleName = "ImportExcel"; ModuleVersion = "7.8.9"}

Param (
    $Mailboxes
)

$ErrorActionPreference = "Stop"

if (-not (Get-ConnectionInformation)) {
    Connect-ExchangeOnline
}

if (-not (Get-MgContext)) {
    Connect-MgGraph -Scopes "User.Read.All"
}

$MailboxPerms = New-Object System.Collections.Generic.List[PSObject]

if (-not $Mailboxes) {
    "Gathering Mailboxes"
    $Mailboxes = Get-Mailbox -ResultSize unlimited -RecipientTypeDetails UserMailbox
}
$i=1
foreach ($Mailbox in $Mailboxes) {    
    Write-Progress -Activity 'Checking Mailboxes' -status "Processing Mailbox: $($Mailbox.DisplayName)" -PercentComplete ($i / $Mailboxes.count*100)
    #Write-Host $Mailbox.DisplayName
    $Filter = "UserPrincipalName eq '{0}'" -f $Mailbox.UserPrincipalName
    $UserId = (Get-MgUser -Filter $Filter).id
    $UserLicenseDetails = Get-MgUserLicenseDetail -UserId $UserId

    If ($UserLicenseDetails.SkuPartNumber -contains "ENTERPRISEPACK") {
        try {
            [array]$Perms = Get-MailboxPermission -Identity $Mailbox.UserPrincipalName |Where-Object {$_.User -like "*@balfourbeattyus.com" -or $_.User -like "*@bbcgrp.com"}
        } catch {
            Throw "$($Mailbox.DisplayName), $($Mailbox.UserPrincipalName)m $($_)"
        }
        foreach ($Perm in $Perms) {
            If ($Perms.IndexOf($Perm) -eq 0) {
                $Owner = $Mailbox.DisplayName
                $UserPrincipalName = $Mailbox.UserPrincipalName
                $RecipientType = $Mailbox.RecipientTypeDetails
            } else {
                $Owner = " "
                $UserPrincipalName = " "
                $RecipientType = " "
            }
            $Permission = [PSCustomObject]@{
                Owner = $Owner
                UserPrincipalName = $UserPrincipalName
                RecipientType = $RecipientType
                User = $Perm.User
                AccessRights = ($Perm.AccessRights -join ",")
                #IsInherited = $Perm.IsInherited
                #Deny = $Perm.Deny
            }
            $MailboxPerms.add($Permission)
        }
    }
    $i += 1
}

$MailboxPerms.ToArray() | Export-Excel -Path "MailboxPermissions.xlsx"

