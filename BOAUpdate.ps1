$Connector = Get-InboundConnector 'BankofAmerica - RECEIVE'
$BOASenderDomains = $Connector.SenderDomains
<#
$BOARemoveDomains = import-csv "../OneDrive/BOA_remove_tls.csv"

[System.Collections.ArrayList]$ar_BOASenderDomains = $BOASenderDomains

foreach($BOARemoveDomain in $BOARemoveDomains) {
    $item = "smtp:$($BOARemoveDomain.Domain);1"
    $ar_BOASenderDomains.Remove($item)
}

Set-InboundConnector -Identity $Connector.Identity -SenderDomains $ar_BOASenderDomains.ToArray()
 #>

$BOAAddSenderDomains = import-csv ../OneDrive/BOA_Add_Forced_TLS.csv
foreach ($BOAAddSenderDomain in $BOAAddSenderDomains) {
    $item = "smtp:$($BOAAddSenderDomain.Domain);1"
    if ( -not $BOASenderDomains.contains($item)) {
        $BOASenderDomains += $BOAAddSenderDomain.Domain
    }
}
Set-InboundConnector -Identity $Connector.Identity -SenderDomains $BOASenderDomains -WhatIf
