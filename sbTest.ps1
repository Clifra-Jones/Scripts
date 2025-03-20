function sACL() {
    Param(
        $Path,
        [bool]$Directory,
        [bool]$File,
        [bool]$Recurse

    )
    function serializeAccessList() {
        Param ($AccessList)
        $Access = @()
        $AccessList | ForEach-Object {
            $AL = [PsCustomObject][Ordered]@{
                FileSystemRights = $_.FileSystemRights
                AccessControlType = $_.AccessControlType.ToString()
                IdentityReference = $_.IdentityReference
                IsInherited = $_.IsInherited
                InheritanceFlags = $_.InheritanceFlags
                PropagationFlags = $_.PropagationFlags
            }
            $Access += $AL
        }
        return $Access
    }
    function serializeACL() {
        Param ($ACL) 
        $cACL = [PSCustomObject][Ordered]@{
            Path = $ACL.Path
            Owner = $ACL.Owner
            Group = $ACL.Group
            Access = serializeAccessList $ACL.Access
            Audit = $ACL.Audit
            Sddl = $ACL.Sddl
        }
        return $cACL
    }

    if ($Directory) {
        if ($Recurse) {
            $ACls = Get-ChildItem -Path $Path -Directory -Recurse | Get-Acl
            $cACLs = @()
            $ACls | foreach-object {
                $cACL = serializeACL $_
                $cAcls += $cACL
            } 
            return $cACLs
        } else {
                $ACL = Get-Acl -Path $Path
                $cACLs = serializeACL $Acl
                return $cACLs
        }
    } elseif ($File) {
        $ACLs = Get-ChildItem -Path $Path -File | Get-Acl
        $cACLs = @()
        $ACls | ForEach-Object {
            $cACL = serializeACL $_
            $cACLs += $cACL
        }
        return $cACLs
    }
}

sacl -Path 'c:\scripts' $true $true