$DLcmds = "$PSScriptRoot\SCPDload.ftp"
$DLDest = "$PSScriptRoot\..\PD92\inbound"
$KeyFile = "$($env:USERPROFILE)\.ssh\eiwo-balfourbeattyus-com.key"

# Download the latest file.
Set-Location $DLDest

$sftpCmd = 'sftp -b "{0}" -i "{1}" eiwo@sftp.balfourbeattyus.com'
$cmd = $sftpCmd -f $DLcmds, $KeyFile

Invoke-Expression -Command $cmd

# Descrypt the files

$gpgCmd = 'gpg -d --pinentry-mode loopback --passphrase P@ssPhr@se4BBII --batch --output "{0}" "{1}"'

$Files = Get-ChildItem $DLDest -File
foreach($File in $Files) {
    Copy-Item -Path $File.FullName -Destination "$DLDest\Backup\"
    $target = $file.FullName.Replace($file.Extension,'')
    $cmd = $gpgCmd -f $target, $file.FullName
    Invoke-Expression -Command $cmd
    Remove-Item -Path $File.FullName
}
