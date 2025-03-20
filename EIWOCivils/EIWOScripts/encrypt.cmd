@echo off
gpg --batch --yes --trust-model always --recipient csenet2 %1
if exist %1.gpg (
	del %1
)
