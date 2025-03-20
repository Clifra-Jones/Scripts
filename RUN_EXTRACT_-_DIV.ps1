Clear-Host


# Drop All Tables to eliminate risk of using stale data if a script fails
##$vSQL = ("sp_INT_UK_HFM_DROP_TABLES") ~ stored procedure does not exist ~ 20190612 ~ jhaley
##Invoke-Sqlcmd -Query $vSQL -ConnectionString "Data Source=localhost;Initial Catalog=hyp_prod;Integrated Security=True;" ~ commented entire line ~ 20190712 ~ jhaley


# Set variables
$vUser = 'pbcsadmin'
$vPass = 'Pound37#'
$vURL = 'https://planning-balfourbeattyus.pbcs.us2.oraclecloud.com/HyperionPlanning/'
$vDomain = 'balfourbeattyus'
$vEPMAutomatePath = 'C:\Oracle\EPM Automate\bin\epmautomate.bat'
$vLogFile = $MyInvocation.MyCommand.Path.Replace('.ps1','.log')
$HFM_Extract_Entities_V = 'MG_V_DIV_MA, MG_V_DIV_SE, MG_V_DIV_FL, MG_V_DIV_TX, MG_V_DIV_NW, MG_V_DIV_CA, MG_V_DIV_CORPORATE_SERVICES'													#  <-- Update entities as necessary
$HFM_Extract_Entities_C = 'MG_C_DIV_SE, MG_C_DIV_SW, MG_C_DIV_WE, MG_C_DIV_RL, MG_C_DIV_CL, MG_C_DIV_CORP'																				#  <-- Update entities as necessary
$HFM_Extract_Entities_EF = '@remove(@relative(MG_Vertical,0),@list(@relative(Elim_V_Total,0),@relative(Elim_BBC_Total,0))), @remove(@relative(MG_Civil,0),@relative(Elim_C_Total,0))'	#  <-- Update entities as necessary

Write-host "Logging in to PBCS"
&$vEPMAutomatePath login $vUser $vPass $vURL $vDomain 1>$vLogFile 2>&1
Write-host "Setting PBCS substitution variables"
&$vEPMAutomatePath setsubstvars all INT_UK_HFM_Extract_Entities=$HFM_Extract_Entities_V', '$HFM_Extract_Entities_C "INT_UK_HFM_Extract_Entities_EF=""$HFM_Extract_Entities_EF""" 1>>$vLogFile 2>&1


# Run all of the data extract / load scripts
.\INT_UK_HFM_BS.ps1
.\INT_UK_HFM_EF.ps1
.\INT_UK_HFM_IS.ps1
.\INT_UK_HFM_BS_INTRA.ps1
.\INT_UK_HFM_IS_INTRA_REV.ps1
.\INT_UK_HFM_IS_JVA_REV.ps1
.\INT_UK_HFM_OFI.ps1
.\INT_UK_HFM_OFI_INTRA.ps1
.\INT_UK_HFM_OFI_JVA.ps1


# GET RECORD COUNTS
$vSQL = ("SELECT * FROM V_INT_UK_HFM_RECORD_COUNTS")
Invoke-Sqlcmd -Query $vSQL -ConnectionString "Data Source=localhost;Initial Catalog=hyp_prod;Integrated Security=True;"


# Pull data from V_INT_UK_V_ACTUAL  and write to a text file for FDMEE.
$vLogFile = $MyInvocation.MyCommand.Path.Replace('.ps1','.log')
$vResultsFile = $MyInvocation.MyCommand.Path.Replace('.ps1','.txt')

Write-host "Running query"
$results = Invoke-Sqlcmd -Query "select * from V_INT_UK_HFM_DIV_02" -ConnectionString "Data Source=localhost;Initial Catalog=hyp_prod;Integrated Security=True;" 

Write-host "Writing results to EXTRACT_DIVISION.txt"
$results | convertto-csv -Delimiter ";" -NoTypeInformation | % { $_ -replace '";"', ';'} | % { $_ -replace "^`"",''} | % { $_ -replace "`"$",''} | out-file "./EXTRACT_DIVISION.txt" -fo -en ascii


Write-host "Process Complete.  See output log for results."

