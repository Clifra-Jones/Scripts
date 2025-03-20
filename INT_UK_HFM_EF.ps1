Clear-Host

##Variables
$vUser = 'pbcsadmin'
$vPass = 'Pound37#'
$vURL = 'https://planning-balfourbeattyus.pbcs.us2.oraclecloud.com/HyperionPlanning/'
$vDomain = 'balfourbeattyus'
$vEPMAutomatePath = 'C:\Oracle\EPM Automate\bin\epmautomate.bat'

$vName = 'INT_UK_HFM_EF'
$vSourceFile =  $MyInvocation.MyCommand.Path.Replace('.ps1','.txt')
$vTargetFile = $MyInvocation.MyCommand.Path.Replace('.ps1','.csv')
$vLogFile = $MyInvocation.MyCommand.Path.Replace('.ps1','.log')




#############################################################
# Run the business rule and download the file
#############################################################

Write-host "Deleting data file"
Remove-Item $vSourceFile

Write-host "Logging in to PBCS"
&$vEPMAutomatePath login $vUser $vPass $vURL $vDomain  | Out-File -FilePath $vLogFile -Append

Write-host "Running rule " $vName
&$vEPMAutomatePath runbusinessrule $vName | Out-File -FilePath $vLogFile -Append

Write-host "Downloading File " $vName
&$vEPMAutomatePath downloadfile ($vName + ".txt") | Out-File -FilePath $vLogFile -Append




#############################################################
# Read the source file, and write to target file.  
# Combine the first two rows into just one row to serve 
# as column names for SQL
#############################################################

Write-host "Deleting target file " $vTargetFile
Clear-Content $vTargetFile

#First Line
$variables = Get-Content $vSourceFile -First 1 
$variables -replace """Account""","" | Add-Content -Path $vTargetFile -NoNewline

#Second Line
$variables = Get-Content $vSourceFile | Select -Index 1 
"$variables" | Add-Content -Path $vTargetFile

#Except for the First and Second lines, Append the Source File to Target File
$File_Content = Get-Content $vSourceFile
$First_Line = $File_Content[0]
$Second_Line = $File_Content[1]
$File_Content | where {$_ -ne $First_Line -and $_ -ne $Second_Line} | Add-Content -Path $vTargetFile


Write-host "Stripping quotes"
(Get-Content $vTargetFile).replace('"', '') | Set-Content $vTargetFile

Write-host "Replace #Mi"
(Get-Content $vTargetFile).replace('#Mi', '0') | Set-Content $vTargetFile


Write-host "Replace SPOT"
(Get-Content $vTargetFile).replace('Spot_', '') | Set-Content $vTargetFile


#Drop Table
$vSQL = ("drop table if exists " + $vName + ";")
Invoke-Sqlcmd -Query $vSQL -ConnectionString "Data Source=localhost;Initial Catalog=hyp_prod;Integrated Security=True;"

#Drop Unpivot Table
$vSQL = ("drop table if exists " + $vName + "_UNPIVOT;")
Invoke-Sqlcmd -Query $vSQL -ConnectionString "Data Source=localhost;Initial Catalog=hyp_prod;Integrated Security=True;"

#Import CSV into new table
$vSQL = ("select * into " + $vName + " from openrowset('MSDASQL','Driver={Microsoft Access Text Driver (*.txt, *.csv)}','select * from C:\HYP_INT\PROD\INT_UK\" + $vName + ".csv')")
Write-host $vSQL  | Out-File -FilePath $vLogFile -Append
Invoke-Sqlcmd -Query $vSQL -ConnectionString "Data Source=localhost;Initial Catalog=hyp_prod;Integrated Security=True;"

#Unpivot 
$vSQL = ("sp_UnpivotPBCSExport '" + $vName + "';")
Invoke-Sqlcmd -Query $vSQL -ConnectionString "Data Source=localhost;Initial Catalog=hyp_prod;Integrated Security=True;"

Write-host "Logging out of PBCS"  | Out-File -FilePath $vLogFile -Append
&$vEPMAutomatePath logout | Out-File -FilePath $vLogFile -Append

Write-host "Process Complete.  See output log for results."