# Add-GroupMembership.ps1
# Author: Cliff Williams
# Revised: 04/08/2020
#
# Synopsys: This script pulls all active Ad accounts that are not members of the supplied AD Groups and adds them to the appripriate Groups.
#
# Paramters
#   Name: ADGroup
#   Type: String Array
#   
#   Name: ADScope
#   Type: String Array
#   Comment:    Scope is the full AD path to the OU where user accounts will be pulled from.
#               Path can be in LDAP or connanical format
#
#   Name: ExcludedScope
#   Type: String Array
#   Comment:    OU to exclude from the search. This OU must be a child of ADScopes.
#               OU is the full path to the OU in either LDAP or connanical format.
#
#   Name: inputFile
#   Type: String
#   Comment. File is a CSV file in the following format.
#       ADGroup,ADScope,ExcludeScope
# Usage:
#   Execute a single Group (Using conanical names)
#   Add-GroupMembership.ps1 -ADGroup 'TestGroup' -ADScope "domain.com/Company/Division" -ExcludeScope "Domain.com/Company/Division/Dallas"
#
# Execute a single group using LDAP names
#   Add-GroupMembership.ps1 -ADGroup 'TestGroup' -ADScope 'ou=Division,OU=Company,DC=Domain,DC=Com" -ExcludeScope "OU=Dallas,OU=Division,OU=Company,DC=Domain,DC=Com"
#
# Execute using an input file
#   Add-GroupMembership.ps1 -inputFile 'adgroups.csv'
#
Param (
    [Parameter(ParameterSetName = 'input', Mandatory = $true)]
    [string]$ADGroup,
    [Parameter(ParameterSetName = 'input', Mandatory = $true)]
    [string]$ADScope,
    [Parameter(ParameterSetName = 'input', Mandatory = $false)]
    [string]$ExcludedScope,
    [string]$inputFile
)

Import-Module ActiveDirectory
Import-Module ConvertADName
$ErrorActionPreference="stop"

#Start-Transcript -Path C:\Scripts\O365Groups.log
function convert-ADPath([string]$path) {
    if ($path.Contains("/")) {
        return Convert-ADName -UserName $path -OutputType "DN"
    } 
    return $path
}

if ($inputFile) {
    $Groups = Import-CSV $inputFile
} else {
    $_group = New-Object -TypeName PSCustomObject -Property @{
        "ADGroup" = $ADGroup
        "ADScope" = convert-ADPath($ADScope)
        "ExcludedScope" = convert-ADPath($ExcludedScope)
    }
    $Groups = @()
    $Groups += $_group
}

foreach ($Group in $Groups) {
    $AdGroup = Get-ADgroup $Group.ADGroup
    $users = Get-ADUser -Properties MemberOf -Filter {Enabled -eq $true} -SearchBase $group.ADScope -SearchScope:Subtree | `
        Where-Object {$_.MemberOf -notcontains $ADGroup.DistinguishedName}
    
    foreach ($user in $users) {
        if (-not $user.Name.EndsWith("$")) {
            if ($Group.ExcludedScope) {
               if ($user.DistinguishedName -notlike "*$($Group.ExcludedScope)") {
                    Add-ADGroupMember -Identity $ADGroup -Members $user.samAccountName
                    "$($user.Name) added to group $ADGroup"
                }
            } else {            
                Add-ADGroupMember -Identity $ADGroup -Members $user.samAccountName 
                "$($user.Name) added to group $ADGroup"
            }
        }
    }
    
    $members = Get-ADGroupMember -Identity $Group.ADGroup
    foreach ($member in $members) {
        write-host "Checking Member $($member.name)"
        $ex_member = Get-ADUser $member.samAccountName
        if ($ex_member.Enabled -eq $false) {
            Remove-ADGroupMember -Identity $Group.ADGroup -Members $ex_member.samAccountName -confirm:$false
            write-host "$ex_member.Name :Removed from $Group.ADGroup"
        } else {
            Write-Host " "
        }
    }
}
#Stop-Transcript
