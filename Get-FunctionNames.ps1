Param (
    [Parameter(Mandatory)]
    [string]$Path,
    [string[]]$Exclude,
    [string]$Filter,
    [switch]$Recurse

)

try {
    $params = @{
        Path = $Path
    }
    if ($Exclude) {
        $params.Add("Exclude", $Exclude)
    }
    if ($Filter) {
        $params.add("Filter", $Filter)
    }
    if ($Recurse) {
        $params.Add("Recurse", $true)
    }

    Get-ChildItem @params | ForEach-Object {
        $Command = Get-Command $_
        $Command.ScriptBlock.Ast.FindAll({$args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst]}, $false).Name
    } | ForEach-Object {
        "'$_',"
    }
} catch {
    throw $_
}