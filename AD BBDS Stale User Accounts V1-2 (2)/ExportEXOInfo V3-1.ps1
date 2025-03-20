
# This script connects to EXO, export all mailboxes and all mailbox statistics to separate text files.
# It's designed to be called from another script, but will default to the BB O365 tenant if called without arguments.
# This is because the MS MG V1 CMDLets and EXO V3 CMDLets are not compatible in the same script due to a librarty conflict.
# V2 of the MG CMDLets is compatible with EXO V3, but is currently in preview and looks unfinished.
# A scheduled task runs this script every 3 hours, starting from midnight each day.
# Calling scripts can check for an existing export, if timing is not super critical.
# There is no transcripting on this script, as it seems to interfere with transcripting in the calling script.
# V3.1 converts the lastUserActionTime into a string of known format, as exporting the datetime object resulted in multiple formats, including mm/dd/yyyy.

#########################################################################
# Params
PARAM (
    [string]$RequestDateTime = (get-date).ToString("dd-MM-yyyy HH-mm"), # $RequestDateTime is used by the calling script to ensure that it picks up the correct output, if it's not using an existing export.
    [string]$appID = 'xxxxxxxxxxxxxxx', # Default is the BB O365 EXO automation app
    [string]$CertificateThumbprint = 'xxxxxxxxxxxxxxxxxxxxxx', # 
    [string]$Organization = 'balfourbeatty.onmicrosoft.com'
)

#########################################################################
# Functions

# Connects to EXO and tests connection
# Example usage: Connect-ToEXO -AppID xxxxxxxxxxxxxxxxx -CertificateThumbprint xxxxxxxxxxxxxxxxxx  -Organization "balfourbeatty.onmicrosoft.com"
Function Connect-ToEXO {
    Param (
        [Parameter(Mandatory=$true)]
        $AppID,
        $CertificateThumbprint,
        $Organization
    )

    DisConnect-ExchangeOnline -Confirm:$False -ea SilentlyContinue | out-Null # This function is likely to be called from a foreach loop, so running a disconnect seems prudent.
    $result = Connect-ExchangeOnline -AppId $AppID -CertificateThumbprint $CertificateThumbprint  -Organization $Organization -ea SilentlyContinue
    $EXOConnection = Get-ConnectionInformation -ea SilentlyContinue
    
    If ($EXOConnection) {
        Write-Host $result
        Return $EXOConnection
    }
    Else {
        Write-Host $result
        Write-Error "Error connecting to EXO $Organization"
    }
}

Function Tidy-Logs {
    # Clean up and finish
    $OldLogs = get-ChildItem "$($scriptPath)\Logs" | Where-Object {$_.LastWriteTime -lt ((get-Date).AddDays(-$LogAndTranscriptRetentionPeriod))}
    $OldLogs | ForEach-Object {remove-Item -Path $_.FullName  -Force -Confirm:$False}
    $OldTranscripts = get-ChildItem "$($scriptPath)\Transcripts" | Where-Object {$_.LastWriteTime -lt ((get-Date).AddDays(-$LogAndTranscriptRetentionPeriod))}
    $OldTranscripts | ForEach-Object {remove-Item -Path $_.FullName  -Force -Confirm:$False}
}

#########################################################################
# Script set up
$scriptPath = split-Path ($MyInvocation.MyCommand.Path) -parent # NOTE - this only works when executing the whole script, not a code selection.
$scriptName = (split-Path ($MyInvocation.MyCommand.Path) -Leaf).Replace(".ps1","") # NOTE - this only works when executing the whole script, not a code selection.
$dateTimeString = (get-date).ToString("dd-MM-yyyy HH:mm")
$LogAndTranscriptRetentionPeriod = 9 # In days
# Start-Transcript -Path "$scriptPath\transcripts\$dateTimeString $scriptName.txt" # No transcripting - all exceptions passed to main script

#########################################################################
# Sript body

# Connect to EXO

# $EXOConnection = Connect-ToEXO -AppID xxxxxxxxxxxxxxxxx -CertificateThumbprint "xxxxxxxxxxxxxxxxxxxxxxxxxxx"  -Organization "balfourbeatty.onmicrosoft.com"
# $AppID = "xxxxxxxxxxxxxxxxxxxxxxxxxx" 
# $CertificateThumbprint = "xxxxxxxxxxxxxxxxxxxxx" 
# $Organization = "balfourbeatty.onmicrosoft.com"
# $RequestDateTime = $dateTimeString

# The scripts that use this one sometimes look for previous exports to save time.  To prevent teh wrong data from being used, i am locking this script down to the 'balfourbeatty.onmicrosoft.com' org.
If ($Organization -ne 'balfourbeatty.onmicrosoft.com') {
    Write-Error "Error connecting to EXO $Organization"
    Tidy-Logs
    EXIT
}

$EXOConnection = Connect-ToEXO -AppID $AppID -CertificateThumbprint $CertificateThumbprint -Organization $Organization

# Connect-ExchangeOnline -AppId $AppID -CertificateThumbprint $CertificateThumbprint -Organization $Organization # -ea SilentlyContinue

get-EXOMailbox -UserPrincipalName "pieter.debruin@balfourbeatty.com"


#[Net.ServicePointManager]::SecurityProtocol
#[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$error[0].Exception

If ($EXOConnection -like "Error *") {
    Write-Error "Error connecting to EXO"
    Tidy-Logs
    Exit
}

# Get mailboxes and mailbox statistics

# Get all the mailboxes
$EXOMailboxes = get-EXOMailbox -ea Stop -ResultSize Unlimited -Properties ExchangeGuid

# Get statistics for all the mailboxes
If ($EXOMailboxes) {
    $EXOMBStastics = $EXOMailboxes | Get-EXOMailboxStatistics -Properties LastUserActionTime,MailboxGuid -ea Stop
}
Else {
    Write-error "Error getting mailboxes"
    Tidy-Logs
    EXIT
}

If ($EXOMBStastics) {
    # Build EXOMAilboxStatistics hashtable for faster lookups.  The MailboxGuid property on an mailbox statistics object corresponds to the ExchangeGuid on a mailbox object, so it is used as the key.
    $EXOMBStasticsHT = @{}
    ForEach ($EXOMBStastic in $EXOMBStastics) {
        $EXOMBStasticsHT.Add($EXOMBStastic.MailboxGuid,$EXOMBStastic)
    }

    # Add lastUserActionTime as a member on the mailbox objects
    ForEach ($EXOMailbox in $EXOMailboxes) {
        $lastUserActionTime = $null
        $lastUserActionTime = ($EXOMBStasticsHT.($EXOMailbox.ExchangeGuid)).LastUserActionTime
        if ($lastUserActionTime) {
            $EXOMailbox | Add-Member -MemberType NoteProperty -Name LastUserActionTime -Value (get-date $lastUserActionTime).ToString("dd/MM/yyyy HH:mm")
        }
        else {
            $EXOMailbox | Add-Member -MemberType NoteProperty -Name LastUserActionTime -Value $null
        }
    }
    
    # Export mailbox data
    $EXOMailboxes | export-csv "$($scriptPath)\Logs\$($RequestDateTime) EXO MailboxObjects.csv"

    Tidy-Logs
}
else {
    Write-Error "Error getting mailbox statistics"
    Tidy-Logs
    EXIT
}
