Param(
    [string]$Name,
    [string]$Group,
    [string]$Server,
    [string]$username,
    [string]$Domain,
    [string]$protocol='rdp',
    [string]$Template,
    [string]$outputFolder
)

$tmpl = Get-Content -Path $Template -Raw

$newProfile = $tmpl -f $Name, $Group, $Server, $username, $Domain
$filename = "{0}-{1}-{2}-{3}.remmina" -f ($group.Replace("/","-")), $protocol, $Name.Replace(".","-"), $Server.Replace(".","-")
$fileName = "$outputFolder/$filename".ToLower()
$newProfile | Set-Content -PassThru $filename 
