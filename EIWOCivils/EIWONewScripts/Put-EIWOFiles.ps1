$ULcmds = "$PSScriptRoot\SCPUpload.ftp"
$ULSource = "$PSScriptRoot\..\PD92\outbound"
$KeyFile = "$($env:USERPROFILE)\.ssh\eiwo-balfourbeattyus-com.key"

Set-Location $ULSource

#Encrypt the files
$gpgCmd = 'gpg --encrypt --batch --yes --trust-model always --recipient csenet2 "{0}"'

$Files = Get-ChildItem -Path "$ULSource\*.XLS" -File
foreach ($File in $Files) {
    Copy-Item -Path $File.FullName -Destination "$ULSource\Backup\"
    $cmd = $gpgCmd -f $File.FullName
    Invoke-Expression -Command $cmd
    Remove-Item -Path $File.FullName
}

$sftpCmd = 'sftp -b "{0}" -i "{1}" eiwo@sftp.balfourbeattyus.com'
$cmd = $sftpCmd -f $ULcmds, $KeyFile
Invoke-Expression -Command $cmd
Remove-Item -Path "*.gpg"
