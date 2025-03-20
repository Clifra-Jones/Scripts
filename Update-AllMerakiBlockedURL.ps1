<#
Name: Meraki Update Script 
Author: Brendan Weir
Version: .2
Description: Adds a URL to the Content Blocked list of the below Meraki templates and networks.

Parameters:
-URL - The url you wish to add to the blocked list, can be a domain name or IP.

Depenedecnies: 
- Must have the Meraki-API module installed created by Cliff Williams (cwilliams@balfourbeattyus.com)
- Must run under PowerShell 7
#>

param ([string] $URL)
#Import-Module Meraki-API
#Location to save URL backups (no trailing \)
$saveLoc = "C:\temp\blockedLists"
#User's API key
$APIkey = 'f966f386e7832c6b1c45c00c5e8827091f713bdd'
#Names of BBC Templates/Networks
$BBCtemplates = "East - Template 3.0", "West - Template 3.0", "Central - Template 3.0", "West - Template 2.0", "Central - Template 2.0", "East - Template 2.0", "Central - Template MX68", "West - Template", "Central - Template", "East - Template"
$BBCnetworks = "East-NC-Charlotte Main Office", "Balfour Wireless", "West-OR-PortlandBuilding-CoLo", "West-WA-MSCR", "East-Atlanta 300 Galleria Office", "Civils-West-Stock-Fairfield-Q2LY-63VG-KSF8", "East-MD-Bowie State", "East-Wilmington-NC-Office", "East-FL -Broward", "East-VA-Hoffman Estates", "West-WA-KingCoCFJC", "East-VA-Upper Saddle River Tax Office", "Civils-Central-TX-Frucon Houston NEWPP", "East-VA-FairfaxOffice", "East-NC-Raleigh Main Office", "East-FL-Plantation Main Office", "East-FL-Orlando Main Office", "Civils-West-CA-Civils La Verne Ca", "Civils-East-VA-Lake Kilby WTP", "Civils-West-CA-Fairfield CA", "Civils-East-VA-Fredericksburg VA", "Civils-RRPJV-Westminster Office", "Civils-West-Woodland CA Office", "West-AZ-Phoenix Office", "West-CA-500 Folsom", "Central-Texas-Austin Main Office", "West-CA-Newport Beach Office", "Civils-East-Goldsboro Office", "Civils-East-Fleming Island", "Central -Corp - Dallas Citymark", "Civils-West-Englewood Office", "East-Switches", "Central-Texas-TFC Capitol Complex CMA", "West-OR-KaiserInterstate", "West-OR-PDXProjects", "Civils-West-Caltrain Office", "West-OR-Portland Main Office", "West-CA-San Diego Office", "West-WA-Seattle Office", "Civils-RRPJV-Commerce City", "Civils-Central-TX-Katy Freeway", "West-CA-Innovations Academy", "Civils-West-STOCK-Fairfield-Q2LY-TZFQ-V925", "BBCUS-API-Test", "Civils-East-NC-Maysville ByPass", "Investments-Audubon_1-1", "West-CA-Stock-Fairfield-Q2PN-TT68-WQH8"
#Names of BBI Templates/Networks
$BBItemplates = "BBC - 24 - Test", "BBC - 26 - NGL", "BBC - 27 - NGL", "Balfour Beatty Communities", "Balfour Beatty Communities - 3IP", "Balfour Beatty Communities -26", "Balfour Beatty Communities VoIP 27"
$BBInetworks = "HA - Audubon", "Malvern - Security"

#Sets working Company to BBI
Set-MerakiAPI -APIKey $APIkey -OrgID 746357
Write-Host "Company set to Balfour Beatty Investments" -ForegroundColor Cyan

#Template URL adding
Write-Host "Templates: Adding $URL to blocked URL list." -ForegroundColor Yellow
foreach ($BBItemplate in $BBItemplates) {
$cfr = Get-MerakiOrganizationConfigTemplates | Where-Object {$_.Name -like $BBItemplate} | Get-MerakiNetworkApplianceContentFiltering
if ($null -ne $cfr) 
    { 
        $cfr.blockedUrlPatterns | Out-File "$saveLoc\$BBItemplate.txt"
        $cfr.blockedUrlPatterns += $URL
        Get-MerakiOrganizationConfigTemplates | Where-Object {$_.Name -like $BBItemplate} | Update-MerakiNetworkApplianceContentFiltering -ContentFilteringRules $cfr | Out-Null
        Write-Host "$BBItemplate is complete." -ForegroundColor Green
    }
    else { Write-Host "$BBItemplate is incorrect"}
}
Write-Host "All BBI templates have been updated." -ForegroundColor Green

#Network URL adding
Write-Host "Networks: Adding $URL to blocked URL list." -ForegroundColor Yellow
foreach($BBInetwork in $BBInetworks) {
    $cfr = Get-MerakiNetworks | Where-Object {$_.Name -like $BBInetwork} | Get-MerakiNetworkApplianceContentFiltering
    if ($null -ne $cfr) 
    { 
        $cfr.blockedUrlPatterns | Out-File "$saveLoc\$BBInetwork.txt"
        $cfr.blockedUrlPatterns += $URL
        Get-merakiNetworks | Where-Object {$_.Name -like $BBInetwork} | Update-MerakiNetworkApplianceContentFiltering -ContentFilteringRules $cfr | Out-Null
        Write-Host "$BBInetwork is complete." -ForegroundColor Green
    }
    else { Write-Host "$BBInetwork is incorrect" }
}
Write-Host "All BBI networks have been updated." -ForegroundColor Green

#Set working company to BBC
Set-MerakiAPI -APIKey $APIkey -OrgID 133945
Write-Host "Company set to Balfour Beatty Construction and Civils" -ForegroundColor Cyan

#Template URL adding
Write-Host "Templates: Adding $URL to blocked URL list." -ForegroundColor Yellow
foreach ($BBCtemplate in $BBCtemplates) {
    $cfr = Get-MerakiOrganizationConfigTemplates | Where-Object {$_.Name -like $BBCtemplate} | Get-MerakiNetworkApplianceContentFiltering
    if ($null -ne $cfr) 
        { 
            $cfr.blockedUrlPatterns | Out-File "$saveLoc\$BBCtemplate.txt"
            $cfr.blockedUrlPatterns += $URL
            Get-MerakiOrganizationConfigTemplates | Where-Object {$_.Name -like $BBCtemplate} | Update-MerakiNetworkApplianceContentFiltering -ContentFilteringRules $cfr | Out-Null
            Write-Host "$BBCtemplate is complete." -ForegroundColor Green
        }
        else { Write-Host "$BBCtemplate is incorrect" }
    }
    Write-Host "All BBC templates have been updated." -ForegroundColor Green

#Network URL adding
Write-Host "Networks: Adding $URL to blocked URL list." -ForegroundColor Yellow
foreach($BBCnetwork in $BBCnetworks) {
    $cfr = Get-MerakiNetworks | Where-Object {$_.Name -like $BBCnetwork} | Get-MerakiNetworkApplianceContentFiltering
    if ($null -ne $cfr) 
    { 
        $cfr.blockedUrlPatterns | Out-File "$saveLoc\$BBCnetwork.txt"
        $cfr.blockedUrlPatterns += $URL
        Get-MerakiNetworks | Where-Object {$_.Name -like $BBCnetwork} | Update-MerakiNetworkApplianceContentFiltering -ContentFilteringRules $cfr | Out-Null
        Write-Host "$BBCnetwork is complete." -ForegroundColor Green
    }
    else { Write-Host "$BBCnetwork is incorrect" }
}

Write-Host "****************************************************************************" -ForegroundColor Cyan
Write-Host "***** Script Complete! All BB Construction networks have been updated. *****" -ForegroundColor Cyan
Write-Host "****************************************************************************" -ForegroundColor Cyan