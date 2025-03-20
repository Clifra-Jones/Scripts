@echo off
P:
cd %1
winscp.com /script=%2
call "C:\E-IWO scripts\DecryptAll.cmd" %1

