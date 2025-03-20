Clear-Host

# Set variables
$vUser = 'pbcsadmin'
$vPass = 'Pound37#'
$vURL = 'https://planning-balfourbeattyus.pbcs.us2.oraclecloud.com/HyperionPlanning/'
$vDomain = 'balfourbeattyus'
$vEPMAutomatePath = 'C:\Oracle\EPM Automate\bin\epmautomate.bat'
$vLogFile = $MyInvocation.MyCommand.Path.Replace('.ps1','.log')
$HFM_Extract_Entities = 'CO_US_Verticals, CO_CAN_Verticals, CO_Civil, CO_97000'                      ##  <-- Update entities as necessary (change CO_97000 to @isiblings(CO_97000) for HQ)
$HFM_Extract_Entities_EF = '@relative(CO_Vertical,0), @relative(CO_Civil,0), @relative(CO_97000,0)'  ##  <-- Update entities as necessary (change CO_97000,0 to CO_HQ,0 for HQ)

# Drop All Tables to eliminate risk of using stale data if a script fails
$vSQL = ("sp_INT_UK_CO_HFM_DROP_TABLES")
Invoke-Sqlcmd -Query $vSQL -ConnectionString "Data Source=localhost;Initial Catalog=hyp_prod;Integrated Security=True;"

# Set substitution variables in PBCS
Write-host "Login to PBCS"
&$vEPMAutomatePath login $vUser $vPass $vURL $vDomain 1>$vLogFile 2>&1
Write-host "Set INT_UK_HFM_Extract_Entities substitution variable"
&$vEPMAutomatePath setsubstvars all INT_UK_HFM_Extract_Entities=$HFM_Extract_Entities 1>>$vLogFile 2>&1
Write-host "Set INT_UK_HFM_Extract_Entities_EF substitution variable"
&$vEPMAutomatePath setsubstvars all "INT_UK_HFM_Extract_Entities_EF=""$HFM_Extract_Entities_EF""" 1>>$vLogFile 2>&1
Write-host "Logout of PBCS"
&$vEPMAutomatePath logout 1>>$vLogFile 2>&1

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

# Pull data from view and write to a text file for FDMEE
##$vLogFile = $MyInvocation.MyCommand.Path.Replace('.ps1','.log')
$vResultsFile = $MyInvocation.MyCommand.Path.Replace('.ps1','.txt')

Write-host "Running query"
$results = Invoke-Sqlcmd -Query "select * from V_INT_UK_HFM_OPCO_02" -ConnectionString "Data Source=localhost;Initial Catalog=hyp_prod;Integrated Security=True;" 

Write-host "Writing results to EXTRACT_OPCO.txt"
$results | convertto-csv -Delimiter ";" -NoTypeInformation | % { $_ -replace '";"', ';'} | % { $_ -replace "^`"",''} | % { $_ -replace "`"$",''} | out-file "./EXTRACT_OPCO.txt" -fo -en ascii

Write-host "Process Complete.  See output log for results."
