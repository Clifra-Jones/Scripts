#Install-Module -Name SharePointPnPPowerShellOnline

$SecurityScope = @("Group.Read.All")
Connect-PnPOnline -Scopes $SecurityScope
$PnPGraphAccessToken = Get-PnPGraphAccessToken
$Headers = @{
        "Content-Type" = "application/json"
        Authorization  = "Bearer $PnPGraphAccessToken"    
}        
$Date = Get-Date -Format "dd.MM.yyyy, HH:mm"
$DOCTYPE = "<!DOCTYPE html PUBLIC '-//W3C//DTD XHTML 1.0 Strict//EN' 'http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd'><html xmlns='http://www.w3.org/1999/xhtml'>"
$Style ="<style>table {border-collapse: collapse; width:100%;} table th {text-align:left; background-color: #004C99; color:#fff; padding: 4px 30px 4px 8px;} table td {border: 1px solid #004C99; padding: 4px 8px;} td {background-color: #DDE5FF}</style>"     
$Head = "<head><title>Backup: Teams-Chat</title></head>"
$Body = "<body><div style='width: 100%;'><table><tr><th style='text-align:center'><h1>Backup: Teams-Chat from $Date</h1></th></tr></table>"               
$Table_body = "<div style='width: 100%;'><table><tr><th>TimeStamp</th><th>User Name</th><th>Message</th></tr>"
$Content =""
$Footer = "</body>"
$response_teams = Invoke-RestMethod -Uri  "https://graph.microsoft.com/beta/groups" -Method Get -Headers $Headers -UseBasicParsing
$response_teams.value | Where-Object {$_.groupTypes -eq "Unified"} | Select-Object -Property displayName, ID  | Out-GridView -PassThru -Title 'Which Team-Chat do you want to backup?' |
ForEach-Object {
    $Team_ID = $_.ID
    $Team_displayName = $_.displayName
    Write-Progress -Activity "Bckup Team Chat Mesasages"  -Status "Get Team: $($Team_displayName)"
    Start-Sleep -Milliseconds 50
    $Content += "</br></br><hr><h2>Team: " + $Team_displayName + "</h2>"
    $response_channels = Invoke-RestMethod -Uri  "https://graph.microsoft.com/beta/teams/$Team_ID/channels" -Method Get -Headers $Headers -UseBasicParsing
    $response_channels.value | Select-Object -Property ID, displayName |
    ForEach-Object {
        $Channel_ID = $_.ID
        $Channel_displayName = $_.displayName
        Write-Progress -Activity "Bckup Team Chat Mesasages"  -Status "Get Channel: $($Channel_displayName)"
        Start-Sleep -Milliseconds 50    
        $Content += "<h3>Channel: " + $Channel_displayName + "</h3>"
        $response_messages = Invoke-RestMethod -Uri  "https://graph.microsoft.com/beta/teams/$Team_ID/channels/$Channel_ID/messages" -Method Get -Headers $Headers -UseBasicParsing
        $response_messages.value | Select-Object -Property ID, createdDateTime, from |
        ForEach-Object {
            $Message_ID = $_.ID
            $Message_TimeStamp = $_.createdDateTime
            $Message_from = $_.from                    
            $response_content = Invoke-RestMethod -Uri  "https://graph.microsoft.com/beta/teams/$Team_ID/channels/$Channel_ID/messages/$Message_ID" -Method Get -Headers $Headers -UseBasicParsing
            Write-Progress -Activity "Bckup Team Chat Mesasages"  -Status "Get Team: $($Team_displayName), Gett Message-ID: $($Message_ID), from Channel: $($Channel_displayName)"
            Start-Sleep -Milliseconds 50                                                         
            $Content += $Table_body + "<td>" + $Message_TimeStamp + "</td><td style='width: 10%;'>" + $Message_from.user.displayName + "</td><td style='width: 75%;'>" + $response_content.body.content + $response_content.attachments.id + "</td></table></div>"
            $response_Reply = Invoke-RestMethod -Uri  "https://graph.microsoft.com/beta/teams/$Team_ID/channels/$Channel_ID/messages/$Message_ID/replies" -Method Get -Headers $Headers -UseBasicParsing
            $response_Reply.value | Select-Object -Property ID, createdDateTime, from |
            ForEach-Object {
                $Reply_ID = $_.ID
                $Reply_TimeStamp= $_.createdDateTime
                $Reply_from = $_.from                        
                $response_Reply = Invoke-RestMethod -Uri  "https://graph.microsoft.com/beta/teams/$Team_ID/channels/$Channel_ID/messages/$Message_ID/replies/$Reply_ID" -Method Get -Headers $Headers -UseBasicParsing
                Write-Progress -Activity "Bckup Team Chat Mesasages"  -Status "Gett Reply-Message-ID: $($Reply_ID)"
                Start-Sleep -Milliseconds 50
                ForEach-Object {                                                                          
                $Content += $Table_body + "<td>" + $Reply_TimeStamp + "</td><td style='width: 10%;'>" + $Reply_from.user.displayName + "</td><td style='width: 75%;'>" + $response_Reply.body.content + $response_Reply.attachments.id + $response_Reply.attachments.name + "</td></table></div>"
                }
            }
        }                                
    }
}
$DOCTYPE + $Style + $Head + $Body + $Content + $Footer |  Out-File -FilePath "C:\Backup.html"
& "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" "C:\Backup.html"