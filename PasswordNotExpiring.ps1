using namespace System.Collections.Generic
$ADAccounts = Import-Csv -Path .\output\UsersNoPWExpire.vsc
$MyAccounts = [List[PSObject]]::New()
foreach ($Account in $ADAccounts) {
    #Write-Host $_.Name
    $Mailbox = Get-Mailbox $Account.UserPrincipalName -ErrorAction SilentlyContinue
    if ($Mailbox) {
        #Write-host "Found Mailbox..."
        $Account | Add-Member -MemberType NoteProperty -Name "HasMailbox" -Value $true
        $Account | Add-Member -MemberType NoteProperty -Name "MailboxNAme" -Value $Mailbox.Name
        $Account | Add-Member -MemberType NoteProperty -Name "RecipientType" -Value $Mailbox.RecipientTypeDetails
        $MsolUser = Get-MsolUser -UserPrincipalName $Account.UserPrincipalName -ErrorAction SilentlyContinue
        if ($MsolUser) {
            $Account | Add-Member -MemberType NoteProperty -Name "IsLicensed" -Value $MsolUser.IsLicensed
        } else {
            $Account | Add-Member -MemberType NoteProperty -Name "IsLicensed" -Value $Null
        }
    } else {
        $Account | Add-Member -MemberType NoteProperty -Name "HasMailbox" -Value $False
        $Account | Add-Member -MemberType NoteProperty -Name "MailboxNAme" -Value $Null
        $Account | Add-Member -MemberType NoteProperty -Name "RecipientType" -Value $Null       
        $Account | Add-Member -MemberType NoteProperty -Name "IsLicensed" -Value $Null
    }
    
    $MyAccounts.Add($Account)
}

$MyAccounts.ToArray() | `
Select-Object Name, UserPrincipalName, Enabled, WhenCreated, @{N="LastLogon";e={[datetime]::FromFileTime($_.LastLogonTieStamp)}}, HasMailbox, `
MailboxName, RecipientType, IsLicensed, Description | Export-Csv .\output\UsersNoPWExpires.csv -NoTypeInformation
