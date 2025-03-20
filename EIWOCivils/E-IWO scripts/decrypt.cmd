@echo off
set target=%1
set target=%target:.gpg=%
echo.%Target%
gpg --pinentry-mode loopback --passphrase P@ssPhr@se4BBII --batch --output %target% --decrypt %1

