param (
    [number]$top = 10,
    [Parameter(
        Mandatory = $true,
    )]
    [String]$Status
)

Switch ($Status) {
    "CPU" {
        $NumberOfLogicalProcessors=(Get-WmiObject -class Win32_processor | Measure-Object -Sum NumberOfLogicalProcessors).Sum -1
        $Counter = "\Process(*0\% Processor Time"
        $counterSamples = Get-Counter $Counter |Select-Object -ExpandProperty CounterSamples | Where-Object {$_.InstanceName -ne 'idle' -and $_.InstanceName -ne '_Total'}
        $Processes = $counterSamples | Sort-Object -Property CookedValue -Descending | Select-Object -First $top InstanceName, `
                    @{Name="Value"; Expression={[math]::Round(($_.CookedValue / $NumberOfLogicalProcessors), 1)}}
        Write-Host ($Processes | ConvertTo-Json)
    }
    "Memory" {
        $Counter = '\Process(*)\Working Set'
        $counterSamples = Get-Counter $Counter | Select-Object -ExpandProperty CounterSamples | Where-Object {$_.InstanceName -ne 'idle' -and $_.instanceName -ne '_Total'}
        $Processes = $counterSamples | Sort-Object -Property CookedValue -Descending | Select-Object -First $top InstanceName, `
                    @{Name="Memory (KB)"; Expression={[math]::Round(($_.CookedValue / 1024/1024), 1)}}
        Write-Host ($Processes | ConvertTo-Json)
    }
}

