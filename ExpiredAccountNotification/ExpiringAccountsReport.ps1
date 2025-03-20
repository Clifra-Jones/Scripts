#Requires -Modules @{ModuleName = 'ImportExcel'; ModuleVersion = '7.8.6'}
#Requires -Modules @{ModuleName = 'ActiveDirectory'; ModuleVersion = '1.0.1.0'}
#Requires -Modules @{ModuleName = 'AWS.Tools.SecretsManager'; ModuleVersion = '4.2.529'}

function SendMessage() {
    Param(
        [object]$User
    )
    $Body = $Body -f ($User.DaysLeft)
      
    $SmtpParams = @{
        SmtpServer = $SESSmtpCreds.SmtpHost
        Port = $SESSmtpCreds.SmtpPort
        From = 'AccountManager@balfourbeattyus.com'
        To = $User.mail
        Bcc = 'cwilliams@balfourbeattyus.com'
        Subject = "ATTENTION: Your Balfour Beatty User Account is about to expire!"
        Body = $Body
        UseSSL = $True
        Credential = $SMTPCredential
        BodyAsHtml = $true
        Priority = "High"
    }

    Send-MailMessage @SmtpParams -WarningAction SilentlyContinue    
    Write-Host "Sent message for $($user.name), Days until deactivated: $($User.DaysLeft)"
}

$Today = Get-Date -Format "MM-dd-yyyy"
$LogDate = Get-Date -Format "MMDDYYY-HHmmss"
$LogFile = "$PSScriptRoot\ExpiredAccountsNOtification_$LogDate.log"

Start-Transcript -Path $LogFile

$FirstWarnDays =  15
$SecondWarnDays = 10
$LastWarnDays = 5

$SearchWords = @(
    "Intern",
    "Consultant",
    "JV",
    "Joint Venture",
    "Temp",
    "Temporary"
)

$Filter = ""
foreach ($word in $SearchWords) {
    if ($Filter) {
        $Filter = "{0} -or" -f $Filter
    }
    $Filter = "{0} (Description -like '*{1}*')" -f $Filter, $word
}

$SESSmtpCreds = (Get-SECSecretValue -SecretId 'SES_SMTP_User').SecretString | ConvertFrom-Json
$SmtpPassword = ConvertTo-SecureString -String $SESSmtpCreds.SmtpPassword -AsPlainText -Force
$SMTPCredential = [pscredential]::New($SESSmtpCreds.SmtpUsername, $SMTPPassword)

$Body = Get-Content -Path "$PSScriptRoot\AccountExpiring.htm"

# testing code. Comment fort production
#$Users = Get-ADUser -Identity cwilliams -properties Mail | Select-Object *, @{Name="DaysLeft"; Expression={3}}

$Filter = "({0} ) -and Enabled -eq `$True -and AccountExpirationDate -ge '{1}'" -f $Filter, $Today
$filter
$Users = Get-ADUser -Filter $Filter -Properties AccountExpirationDate, Description, Enabled, Mail | `
            Select-Object *, @{Name = "DaysLeft";Expression = {[int]($_.AccountExpirationDate - (Get-Date)).TotalDays}}

$FirstWarnUsers = $Users | Where-Object {$_.DaysLeft -eq $FirstWarnDays}
$SecondWarnUsers = $Users | Where-Object {$_.DaysLeft -eq $SecondWarnDays}
$LastWarnUsers = $Users | Where-Object {$_.DaysLeft -le $LastWarnDays}

<# $FirstWarnUsers
$SecondWarnUsers
$LastWarnUsers
exit #>
Foreach ($user in $FirstWarnUsers) {   
    SendMessage -User $User
}

Foreach ($user in $SecondWarnUsers) {
    SendMessage -User $User
}

Foreach ($User in $LastWarnUsers) {
    SendMessage -User $User
}

Stop-Transcript