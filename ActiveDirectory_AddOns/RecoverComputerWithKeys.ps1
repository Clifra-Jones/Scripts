#Requires -Modules @{ModuleName="ActiveDirectory"; ModuleVersion="1.0.0.0"}

function Recover_Object {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [Object]$RestoredObject
    )

    $recoveryinfos = Get-ADObject -IncludeDeletedObjects -Filter {lastKnownParent -eq $restoredobject.DistinguishedName -and Deleted -eq $True -and objectClass -eq 'msFVE-RecoveryInformation'}
    ForEach($recoveryinfo in $recoveryinfos)
    {
      If ($recoveryinfo)
      {
        "Recovery information found, trying to restore..."
        $recoveryinfo | Restore-ADObject
        Start-Sleep -s 5
        $restoredinfo = Get-ADObject -Filter {ObjectGUID -eq $recoveryinfo.ObjectGUID}
        If ($restoredinfo)
        {
          "Recovery information successfully restored."
        }
        Else
        {
          "Could not restore recovery information, aborting script."
          return $false
        }
      }
      Else
      {
        "No recovery information found for computer object, aborting script."
        return $true
      }
    }
}

function RestoreComputer($computername)
{
  If ($computername.substring($computername.length - 1, 1) -ne '$')
  {
    $computername += '$'
  }

  $existing = Get-ADObject -Filter {sAMAccountName -eq $computername}
  If (!$existing)
  {
    "No existing computer object found, searching for deleted objects."
    $deleted = Get-ADObject -IncludeDeletedObjects -Filter {sAMAccountName -eq $computername -and Deleted -eq $True}
    If ($deleted)
    {
      "Deleted object found, trying to restore…"
      $deleted | Restore-ADObject
      Start-Sleep -s 5
      $restoredobject = Get-ADObject -Filter {sAMAccountName -eq $computername}
      If ($restoredobject)
      {
        "Computer object successfully restored. Trying to find recovery information…"
        $Result = Recover_Object -RestoredObject $restoredobject
        If ($Result)
        {
          "Recovery of computer object succeeded."
          "Finished."
          return $true
        }
        Else
        {
          "Something went wrong. Could not find recovery information in AD Object, aborting script."
          return $false
        }
      }
      Else
      {
        "Something went wrong. Could not find restored object, aborting script."
        return $false
      }
    }
    Else
    {
      "No deleted computer found, aborting script"
      return $false;
    }
  }
  Else
  {
    "Computer already exists, try to recover keys"
    $ComputerObject = Get-ADObject -Filter {sAMAccountName -eq $computername}
    If ($ComputerObject) {
     return recoverKeys $ComputerObject
    }
    return $false
  }
  "Restore of computer object succeeded."
  "Finished."
  return $true
}

$cn = Read-Host "Computername to restore?"

RestoreComputer($cn)