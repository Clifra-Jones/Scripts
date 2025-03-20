#Requires -Modules MicrosoftTeams,Microsoft.online.sharepoint.Powershell

Get-CsOnlineUser | ForEach-Object {
    $OnedriveName = $_.UserPrincipalName.Replace("@","_").Replace(".","_")
    try {
        $Identity = "https://balfourbeattyus-my.sharepoint.com/personal/$OnedriveName"
        $ODFBStorageUsage = (Get-SPOSite -Identity $Identity -ErrorAction SilentlyContinue).StorageUsageCurrent
        Write-Host "$($_.UserPrincipalName), Storage Used $ODFBStorageUsage"
    } catch {
        Write-Host "Failed to get URL $Identity"
    }
}