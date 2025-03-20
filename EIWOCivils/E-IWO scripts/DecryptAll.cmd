::@echo off
I:
cd %1
for %%f in (*.gpg) do (
	copy %%~nxf Backup
	call "I:\EIWOCivils\E-IWO scripts\decrypt.cmd" %%~nxf
	if exist %%~nxf (
		del %%~nxf
	)
)
