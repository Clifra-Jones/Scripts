$URL = 'quantumworkplace.com'

$Networks = Get-MerakiOrganizationConfigTemplates


foreach ($Network in $Networks) {
    $Network.Name
    $Updated = $false
    $BlockedPatterns = ($Network | Get-MerakiNetworkApplianceContentFiltering).BlockedURLPatterns
    $AllowedPattern = ($Network | Get-MerakiNetworkApplianceContentFiltering).AllowedURLPatterns
    $BlockedCategories = ($Network | Get-MerakiNetworkApplianceContentFiltering).BlockedURLCategories
    $CategoryListSize = ($Network | Get-MerakiNetworkApplianceContentFiltering).urlCategoryListSize
    if ($BlockedPatterns.where({$_ -eq $URL})) {
        $BlockedPatterns = $BlockedPatterns | Where-Object {$_ -ne $URL}
        $Updated = $true
    }

    if (-not $AllowedPattern.where({$_ -eq $URL})) {
        $Updated = $true
        $AllowedPattern += $URL
    }

    If ($Updated) {
        $Network | Update-MerakiNetworkApplianceContentFiltering -blockedURLPatterns $BlockedPatterns -allowedURLPatterns $AllowedPattern `
            -blockedUrlCategories $BlockedCategories -urlCategoryListSize $CategoryListSize
    }
}