Param( 
    [Parameter(
        Mandatory = $true
    )]
    [String] $ProcessName,
    [Parameter(
        Mandatory = $true,
        ParameterSetName = "CPU"
    )]
    [Switch] $CPU,
    [Parameter(
        Mandatory = $true,
        ParameterSetName="Memory"
    )]
    [Switch] $Memory
)

$NumberOfLogicalProcessors=(Get-WmiObject -class Win32_processor | Measure-Object -Sum NumberOfLogicalProcessors).Sum -1

if ($CPU) {
    $Counter = "\Process({0})\% Processor Time" -f $ProcessName
    $cookedValue = ((Get-Counter $Counter).Countersamples).cookedValue
    $value = [math]::Round(($cookedValue) / $NumberOfLogicalProcessors , 1)
    write-host $value
}

If ($Memory) {
    $Counter = "Process({0})\Working Set" -f $ProcessName
    $cookedValue = ((Get-Process $Counter).Countersamples).cookedValue
    $Value = [math]::Round(($CookedValue)/1023/1024 ,1)
    Write-Host $value
}