Param(
    [string]$ADSearchRoot
)

Start-Transcript -Path "$PSScriptRoot\pwNotice_transcript.log"

$PasswordExpired = 90
$FirstWarnAge = $PasswordExpired -16
$SecondWarnAge = $PasswordExpired - 11
$LastWarnAge = $PasswordExpired - 6

$outfile =  ".\passwordNotice.log"
"Start: {0}" -f (Get-Date).ToLongDateString() | Out-File $outfile -Force

function SendMessage($userList) {
    foreach ($User in $userList) {
        $from = "PWExpiration@balfourbeattyus.com"
        $to = @()
        $bbc = @()
        $Subject = "Password expiration notice"
        if (-not $user.mail) {
            if ($user.SAMAccountName -like "x-*") {
                $pUser = Get-ADUser ($user.SAMAccountName -replace "x-")
                if (-not $pUser.mail) {
                    Write-Host "$($puser.name), $($osuer.SamAccountName) has no email address"                    
                } else {
                    $To += $puser.mail
                    $Subject += " for $($user.UserPrincipalName)"                    
                }
            } else {
                Write-Host "$($user.name), $($user.SAMAccountName) has no email address"
            }
        } else {
            $to += $user.mail
            $Subject += " for $($user.UserPrincipalName)"
        }
        $bcc += "PWExpiration@balfourbeattyus.com"
        $bcc += "cwilliams@balfourbeattyus.com"
        $days = 90 - $user.PasswordAge.days
        $body =($msg -f $days)
        
        $emailArguments = @{            
            SmtpServer = $SMTPServer 
            Port = $SMTPPort 
            From = $from
            To = $to 
            Bcc = $bbc 
            Subject = $Subject 
            Body = $body 
            UseSsl = $true 
            Credential = $smtpCreds 
            BodyAsHtml = $true 
            Attachments = "$PSScriptRoot\outlook2.png"
        }

        try {            
            # uncomment for production
            #$emailarguments.to = "cwilliams@balfourbeattyus.com" 
            #$emailArguments.remove("Bcc")
            # 
            Send-MailMessage @emailArguments
        } catch {
            throw $_.Exception.Message
        }
    }
}

$MyCreds = (Get-AWSCredential -ProfileName 'default').GetCredentials()

try {
    $myIamUser = Get-IAMUser
} catch {
    throw $_
}

if ($myIamUser.Tags.Count -eq 0) {
    throw "SecretName tag not on user."
}

$Tags = $myIamUser.Tags
$secretName = $Tags[$Tags.Key.IndexOf("SecretName")].value

$MySecretAccessKeys = (Get-SECSecretValue -SecretId $secretName).SecretString | ConvertFrom-Json

if ($MyCreds.AccessKey -ne $MySecretAccessKeys.AccessKeyId) {
    $profileLocation = "$home\.aws\credentials"
    Set-AWSCredential -AccessKey $MySecretAccessKeys.AccessKeyId -SecretKey $MySecretAccessKeys.SecretAccessKey -StoreAs 'default' -ProfileLocation $profileLocation
    Set-AWSCredential -ProfileName 'default'
    Write-Host "Updated local profile from Secrets Manager"
}

$SES_Creds = (Get-SECSecretValue -SecretId 'SES_SMTP_User').SecretString | ConvertFrom-Json
$SMTPServer = $SES_Creds.SmtpHost
$SMTPPort = $SES_Creds.SmtpPort
$SMTPUser = $SES_Creds.SmtpUsername
$smtpPW = ConvertTo-SecureString -String $SES_Creds.SmtpPassword -AsPlainText -Force
$SMTPCreds = [System.Management.Automation.PSCredential]::New($SMTPUser,$smtpPW)

$msg = Get-Content -Path "$PSScriptRoot\PasswordChange.htm"

Write-Host "Gathering ADUsers"

$allAdUsers = Get-ADUser -Properties * -Filter {Enabled -eq $true} -SearchBase $ADSearchRoot -SearchScope Subtree
$adUsers = $allAdUsers | Where-Object {$_.extensionAttribute6 -eq 'user' -and $_.PasswordNeverExpires -ne $true}
$adusers = $adusers | Select-Object *, @{Name="PasswordAge"; Expression={(Get-Date) - ($_.PasswordLastSet)}}

Write-Host "Gathered $($adusers.count)"

$FirstWarnUsers = $adUsers | Where-Object {$_.PasswordAge.Days -eq $FirstWarnAge}
Write-Host "First warn users: $($FirstWarnUsers.Count)"
if ($FirstWarnUsers) {
    SendMessage $FirstWarnUsers
}

$SecondWarnUsers = $adUsers | Where-Object {$_.passwordAde.Days -eq $SecondWarnAge}
Write-Host "Second warn users: $($SecondWarnUsers.Count)"
if ($SecondWarnUsers) {
    SendMessage $SecondWarnUsers
}

$LastWarnUsers = $adUsers | Where-Object {($_.PasswordAge.Days -ge $LastWarnAge) -and ($_.PasswordExpired -eq $false)}
Write-Host "Last warn users: $($LastWarnUsers.Count)"
if ($LastWarnUsers) {
    SendMessage $LastWarnUsers
}

Stop-Transcript
