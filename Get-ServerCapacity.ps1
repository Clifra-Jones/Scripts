[CmdletBinding()]
Param(
    [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
    [String]$ComputerName
)

Begin {
    $PSO = New-PSSessionOption -SkipCACheck -SkipCNCheck
}

Process {
    $Volumes = Invoke-Command -ComputerName $ComputerName -ScriptBlock {Get-Volume} -SessionOption $PSO -UseSSL
    $Volumes
}