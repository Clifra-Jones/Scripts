Param (
    $ComputerName,
    $SourceFile
)
$SourceName = (Get-item $sourceFile).name
if ( -not (Test-Path -Path "\\$ComputerName\C$\temp")) {
    New-Item -Path "\\$ComputerName\c$\temp" -ItemType:Directory
}
Copy-Item -Path $SourceFile -Destination "\\$ComputerName\c$\temp\$SourceName" -Force -Verbose
$FilePath = '"c:\temp\{0}"' -f $SourceName
Invoke-Command -ComputerName $ComputerName -ScriptBlock {Start-Process -FilePath "$using:FilePath" -ArgumentList "/s" }