Import-Module ActiveDirectory

$filter = 'Enabled -eq $true -and (Title -like "*President*" -or Title -like "*VP*" -or Title -like "*CEO*" -or Title -like "*CIO*" -or Title -like "*/COO*" -or Title -like "*Officer*")'
$Executives = Get-ADUser -Properties * -Filter $filter
$ADGroup = Get-ADgroup 'AllBldgsCivilsSeniorLeadersSecurityGroup'

$execUserNames = $Executives.samAccountName

Add-ADGroupMember $AdGroup -Members $execUserNames

