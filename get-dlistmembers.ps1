$dlists = import-csv .\Dlists.csv

$DlistMembers = New-Object 'System.Collections.Generic.List[psobject]'

foreach ($dlist in $Dlists) {
    "Processing group {0}" -f $dlist.name
    $members = Get-DistributionGroupMember $dlist.guid -resultsize unlimited
    foreach ($member in $members) {
        $lMember = [PSCustomObject]@{
            DList = $dlist.Name
            Name = $member.Name
            Username = $member.SamAccountName
        }
        $DlistMembers.add($lMember)
    }
}
$DlistMembers.ToArray() | export-csv DistributionLIsts.csv