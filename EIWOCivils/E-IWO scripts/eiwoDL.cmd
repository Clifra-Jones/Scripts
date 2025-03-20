::@echo off
I:
cd %1
sftpc eiwo@sftptest.bbiius.com:2222 -pw=P@ss4eiwo -cmdFile=%2
call "I:\EIWOCivils\E-IWO scripts\DecryptAll.cmd" %1

