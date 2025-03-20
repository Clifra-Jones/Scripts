function Get-OldestEmail
{
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory=$true,ValueFromPipeline)]
        [object[]]$Mailbox,
        $serverName,
        $Database
    )

    Begin {
        $NewResults = New-Object System.Collections.ArrayList
    }

    Process {  
       if (`
            (`
              (-not $serverName -and -not $Database) `
            ) -or `
            (($serverName -and -not $database) -and ($servername -eq $Mailbox.servername)) -or `
            (($Database -and -not $serverName) -and ($Database -eq $mailbox.database)) -or `
            (($servername -and $database) -and (($Database -eq $mailbox.database) -and ($servername -eq $mailbox.Servername))) `
        ) {  
            $OldestDate = Get-MailboxFolderStatistics -IncludeOldestAndNewestItems -Identity $Mailbox.alias | `
                        Where-Object {$_.OldestItemReceivedDate -ne $null} | Sort-Object OldestItemREceivedDate | `
                        Select-object -First 1 OldestItemRecievedDate
 
            If ($oldestDate) {
                $mailbox | Add-Member -MemberType NoteProperty -Name "OldestItemDate" -Value $OldestDate
            } else {
                $mailbox | Add-Member -MemberType NoteProperty -Name "OldestItemDate" -Value $null
            }
            $NewResults.add($Mailbox)
        }
    }
    End {
        $results = $NewResults.ToArray()
        return $results
    }
}