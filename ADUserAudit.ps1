using namespace System.Collections.Generic

Param(
    [string]$SearchBase,
    [string[]]$Properties,
    [scriptblock]$Filter,
    [Parameter(Mandatory)]
    [string]$AppIdSecret,
    [string]$Domain
)

$Accounts = [List[PsObject]]::New()

$ExoAppIds = Get-Secret -Name $AppIdSecret -AsPlainText | ConvertFrom-Json

if (-not $Filter) {
    $Filter = '*'
}

$Params = @{
    Filter = $Filter
    Properties = $Properties
}
If ($SearchBase) {
    $params.Add("SearchBase" , $SearchBase)
}
If ($Domain) {
    $Params.Add("Server", $Domain)
}

$ADUsers = Get-Aduser -Filter $Filter -Properties $Properties @params

Connect-ExchangeOnline -AppId $ExoAppIds.ClientId -CertificateThumbprint $ExoAppIds.CertificateThumbprint -Organization 'balfourbeattyus.com'
 
Foreach ($ADUser in $ADusers) {
    $percentComplete = (($ADusers.IndexOf($ADUser)) / $ADUsers.count ) * 100
    Write-Progress -Activity "Processing Account:" -Status $ADUser.Name -PercentComplete $percentComplete
    $Mailbox = Get-ExoMailbox $AdUser.UserPrincipalName -ErrorAction SilentlyContinue
    if ($Mailbox) {
        $recipientTypeDetail = $Mailbox.RecipientTypeDetails
    } else {
        $recipientTypeDetail = "n/a"
    }
    $Props = @{
        Name = $ADUser.Name
        SamAccountName = $ADUser.SamAccountName
        UserPrincipalName = $ADUser.UserPrincipalName
        RecipientType = $recipientTypeDetail
    }
    If ($Properties) {
        $Properties | ForEach-Object {
            if ($_ -eq 'LastLogon') {
                $props.Add($_, [datetime]::FromFileTime($ADUser.LastLogon).ToShortDateString())
            } elseif ($_ -eq "LastLogonTimestamp") {
                $Props.Add($_, [datetime]::FromFileTime($ADUser.LastLogonTimeStamp).ToShortDateString())
            } else {
                $Props.Add($_, $ADUser.$_)
            }
        }
    }
    $Account = [PsCustomObject]$Props
    $Accounts.Add($Account)
}
$SelectProperties = @('Name','SamAccountName','UserPrincipalName','RecipientType')
$SelectProperties += $Properties

$Accounts.ToArray() | Select-Object -Property $SelectProperties | Export-csv -Path .\output\ADAccountAudit.csv