
#Requires -Modules @{ModuleName = 'ConvertADName'; ModuleVersion = '1.0.0.0'} 
Param (
    [Parameter(Mandatory)]
    [string]$SearchBase,
    [Parameter(Mandatory)]
    [int]$TimeSpan,
    [string]$MoveTo,
    [switch]$LeaveEnabled,
    [switch]$SendReport,
    [string[]]$Recipients
)

$Domain = (Get-ADDomain).DnsRoot

# Convert AD Paths if needed
if ($SearchBase.Contains("/") -or $SearchBase.Contains(".")) {
    $SearchBase = Convert-ADName -UserName $SearchBase -OutputType:DN
}

if ($MoveTo.Contains("/")) {
    $MoveTo = Convert-ADName -UserName $MoveTo -OutputType:DN
}

$RunDate = (Get-Date).ToShortDateString()

$endDate = (Get-Date).AddDays($TimeSpan * -1)

$Filter = {Enabled -eq $true -and LastLogonDate -lt $endDate -and extensionAttribute6 -eq 'user'}

$Params = @{
    Properties  = @('LastLogonDate', 'Enabled', 'extensionAttribute6')
    SearchBase  = $SearchBase
    SearchScope = 'SubTree'
    Filter      = $Filter
}

$StaleUsers = Get-ADUser @Params

if (-not $LeaveEnabled) {
    # Disabled the accounts
    $StaleUsers | Disable-ADAccount
}

if ($MoveTo) {
    # Check in MoveTo OU exists
    if (-not (Get-ADOrganizationalUnit -Identity $MoveTo)) {
        Throw "The MoveTo Organizational Unit, $MoveTo, does not exist!"
    }
    # Move the accounts
    $StaleUsers | Move-ADObject -TargetPath $MoveTo
}

# Write report
$filename = "$PSScriptRoot/StaleUsers.csv"

$StaleUsers = $StaleUsers.SamAccountName | Get-ADUser -Properties 'LastLogonDate', 'Enabled', 'extensionAttribute6'

$StaleUsers | Select-Object Name, SamAccountName, LastLogonDate, Enabled, @{Name = 'MoveDate';e={$RunDate}}, @{Name = 'MovedTo';Expression={$MoveTo}} | Export-csv -Path $filename

# Send notification if required
if ($SendReport) {
    #Modify for bbcgrp.
    $smtpCreds = (Get-SECSecretValue -SecretId 'SES_SMTP_User').SecretString | ConvertTo-Json
    $pw = ConvertTo-SecureString -String $smtpCreds.SmtpPassword -AsPlainText -Force
    $creds = [PsCredential]::New($smtpCreds.SmtpUsername, $pw)

    $Params = @{
        SMtpServer  = $smtpCreds.SmtpHost
        Port        = $smtpCreds.SmtpPort
        From        = 'StaleAccountReport@balfourbeattyus.com'
        To          = $Recipients
        Subject     = "Stale user report for $Domain"
        $body       = "Attached is the stale user account for $Domain"
        Attachments = $filename
        Credential  = $creds
        UseSSL      = $true
    }

    Send-MailMessage @Params
}