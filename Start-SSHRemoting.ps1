Param(
    [string]$Hostname,
    [String]$Username,
    [string]$Passwd,
    [string]$OTPC
)

if (-not $Hostname) {
    $Hostname = Read-Host -Prompt "Hostname: "
}

if (-not $Username) {
    $username = Read-Host -Prompt "Username: "
}

if (-not $Passwd) {
    $Passwd = Read-Host -Prompt "Password: "
}

if (-not $OTPC) {
    $OTPC = Read-Host -Prompt "Passcode: "
}

$User = "{0}-{1}" -f $Username, $OTPC
$Password = ConvertTo-SecureString -String $Passwd -AsPlainText -Force

$Creds = [System.Management.Automation.PSCredential]::New($User, $Password)

Enter-PSSession -HostName $Hostname -Credential $Creds
