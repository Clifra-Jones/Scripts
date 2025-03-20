$Processes = Get-Process | Select-Object Name

Write-Host ($Processes | ConvertTo-Json)
