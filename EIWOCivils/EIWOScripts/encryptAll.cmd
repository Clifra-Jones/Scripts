::@echo off
I:
cd %1
for %%f in (*.XLS) do (
	copy %%~nxf Backup
	gpg --encrypt --batch --yes --trust-model always --recipient csenet2 %%~nxf
)

for %%f in (*.gpg) do (
	if exist %%~nf (
		del %%~nf
	)
)