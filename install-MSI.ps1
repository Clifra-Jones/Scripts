Param(
    [string]$sourceFile,
    [string]$remoteFolder,
    [string]$ComputerName
)
$fileName = (Get-Item $sourceFile).Name   

if (-not (Test-Path "\\$ComputerName\c$\$remoteFolder")) {
    $folder = "C:\$remoteFolder"
    $sb = [scriptblock]::Create("New-Item -ItemType Directory -Path $folder")
    Invoke-Command -ComputerName $ComputerName -ScriptBlock $sb
}
Start-Sleep -Seconds 5

Copy-Item $sourceFile "\\$computerName\c$\$remoteFolder\"

$p="c:\$remoteFolder\$fileName"

$sb = [scriptblock]::Create("Start-Process -FilePath 'msiexec.exe' -ArgumentList '/i $p /q /norestart' -verb runas -wait")

Invoke-Command -ComputerName $ComputerName -ScriptBlock $sb
