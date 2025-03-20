using namespace System.Management.Automation
using namespace System.Collections.Generic

#Requires -Modules Meraki-API-V1,AWS.Tools.SecretsManager

$DateString = get-date -Format "ddMMyyyy"
$ReportName = "MerakiWanIPs-{0}.csv" -f $DateString
# $Recipients = @(
#     #'ggamboa@balfourbeattyus.com',
#     'cwilliams@balfourbeattyus.com'#,
#     #'gshort@balfourbeattyus.com'
# )


# # Get SES Credentials from Secrets Manager
# $SES_Creds = (Get-SECSecretValue -SecretId 'SES_SMTP_User').SecretString | ConvertFrom-Json

# # Configure Mail parameters
# $SmtpUser = $SES_Creds.SmtpUsername
# $SmtpPass = ConvertTo-SecureString -AsPlainText -String $SES_Creds.SmtpPassword -Force
# $smtpCreds = New-Object PSCredential($SmtpUser, $SmtpPass)
# $SmtpHost = $SES_Creds.SmtpHost
# $SmtpPort = $SES_Creds.SmtpPort

$Networks = Get-MerakiNetworks 
$Networks += Get-MerakiNetworks -profileName 'bbcgrp'
<# $Devices = foreach ($Network in $Networks) {
    Get-MerakiNetworkDevices -id $Network.id
}
$MxDevices = $Devices.where({$_.model -like "MX*"})


$MxDevices | Select-Object Name, Wan1Ip, Wan2Ip | Export-Csv $ReportName #>
$Orgs = Get-MerakiOrganizations
$DeviceStatuses = foreach ($Network in $Networks) {
    Write-Host $Network.Name
    $OrgName = $Orgs.Where({$_.Id -eq $Network.organizationId}).Name
    $Appliances = Get-MerakiNetworkDevices -Id $Network.Id | Where-object {$_.Model -like "MX*"}
    foreach ($Appliance in $Appliances) {
        if ($Appliance) {
            $DeviceStatus = Get-MerakiOrganizationDeviceStatus -OrgId $Network.OrganizationId | Where-Object {$_.Serial -eq $Appliance.Serial}
            if ($DeviceStatus.status -eq 'online') {
                $DeviceStatus | Add-Member -MemberType NoteProperty -Name "Organization" -Value $OrgName
                $DeviceStatus
            }
        }
    }
}

$DeviceStatuses | Select-Object Organization, NetworkName, PublicIp | Export-csv -Path $ReportName

# $Body = "Meraki WAN IP report for {0}" -f (Get-Date)
# $Attachments = ".\{0}" -f $ReportName

# $SmtpParams = @{
#     SmtpServer = $SmtpHost
#     Port = $SmtpPort
#     To = $Recipients
#     From = 'MerakiReport@balfourbeattyus.com'
#     Subject = "Meraki Wan IP Report"
#     Body = $Body
#     Attachments = $Attachments
#     UseSSL = $true
#     Credential = $smtpCreds
# }

# Send-MailMessage @SmtpParams
