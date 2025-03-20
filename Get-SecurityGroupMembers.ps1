#Requires -Modules ActiveDirectory
using namespace System.Collections.Generic

$List = [List[PSObject]]::New()

$SecurityGroups = Get-ADGroup -Filter {GroupCategory -eq 'Security'}

foreach ($SecurityGroup in $SecurityGroup) {
    $Members = Get-ADGroupMember -Identity $SecurityGroup.
}