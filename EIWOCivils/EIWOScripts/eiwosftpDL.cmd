::@echo off
I:
cd %1
sftp -b %2 -i %USERPROFILE%/.ssh/eiwo-balfourbeattyus-com.key eiwo@sftp.balfourbeattyus.com %1
call "I:\EIWOCivils\E-IWO scripts\DecryptAll.cmd" %1

