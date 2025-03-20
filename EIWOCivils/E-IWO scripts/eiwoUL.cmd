::@echo off
I:
call encryptAll %1
sftpc eiwo@sftptest.bbiius.com:2222 -pw=P@ss4eiwo -cmdFile=%2
p:
cd %1
del *.gpg 
