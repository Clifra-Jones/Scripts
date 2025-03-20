Param (
    [string]$SearchBase
)

if ($SearchBase.Contains('/')) {
    $SearchBase = Convert-ADName -UserName $SearchBase -OutputType DN
}

$ADUsers = Get-ADUser -SearchBase $SearchBase -Filter * -Properties LastLogonDate,PasswordLastSet,extensionAttribute6, whenCreated | Sort-Object Name

$ExoAppIds = Get-Secret -Name 'ExoAppId' -AsPlainText | ConvertFrom-Json

Connect-MgGraph -AppId $ExoAppIds.ClientId -TenantId $ExoAppIds.TenantId -CertificateThumbprint $ExoAppIds.CertificateThumbprint


foreach ($ADUser in $ADUsers) {
    Write-host "Processing User: $($ADUser.Name)"
    $UserId = (Get-MgBetaUser -UserId $ADUser.UserPrincipalName -ErrorAction SilentlyContinue).id
    Clear-Variable -Name AzureLogonDate
    if ($UserId) {
        $MgUser = Get-MgBetaUser -UserId $UserId -Property SignInActivity

        Try {
            $AzureLogonDate = $MgUser.SignInActivity.LastSuccessfulSignInDateTime
        } catch {
            Write-host $MgUser.SignInActivity.LastSuccessfulSignInDateTime
        }

    }
    
    $ADUser | Add-Member -MemberType NoteProperty -Name "AzureLogonDate" -Value $AzureLogonDate -Force
   # Write-Output $ADUsers
}

$ADUsers | Select-Object Name, whenCreated, LastLogonDate, PasswordLastSet, AzureLogonDate, extensionAttribute6 | Export-Csv -Path StaleAccountAudit.csv -NoTypeInformation