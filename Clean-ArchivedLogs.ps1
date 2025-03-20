Param (
    [Parameter(Mandatory)]
    [string]$LogPath,
    [Parameter(Mandatory)]
    [string]$LogName,
    [Parameter(Mandatory)]
    [int]$Days
)

$LogPrefix = "Archive-{0}*.*" -f $LogName

$OlderThan = (Get-Date).AddDays($Days * -1)

Remove-Item -Path $LogPrefix -Filter {LastWriteTime -lt $OlderThan} -whatif



