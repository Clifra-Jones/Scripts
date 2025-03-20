$JaxGroups = [System.Collections.Generic.List[psobject]]::New()
$JaxADGroups = Get-ADGroup -Filter {Name -like "JAX-*"}

$JaxADGroups |%{
    $JaxAdGroup = [psCustomObject]@{
        Name = $_.Name
        GroupCategoty = $_.GroupCategory
        GroupScope = $_.GroupScope
        SamAccountName = $_.SamAccountName
    }
    $Members = Get-ADGroupMember -Identity $_.SamAccountName
    if ($Members) {
        $GroupMembers = [System.Collections.Generic.List[psobject]]::new()
        foreach ($Member in $Members) {
            $GroupMember = [psCustomObject]@{
                SamAccountName = $member.SamAccountName
            }
            $GroupMembers.Add($GroupMember)
        }
        $JaxAdGroup | Add-Member -MemberType NoteProperty -Name "Members" -Value ($GroupMembers.toarray())
    }
    $JaxGroups.Add($JaxAdGroup)
}
$JaxGroups.ToArray()