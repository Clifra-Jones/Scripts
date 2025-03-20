# Connect to MS Graph
Connect-MgGraph -Scopes "Group.ReadWrite.All", "User.Read.All", "User.Invite.All"

# Get the Group ID
$groupId = (Get-MgGroup -Filter "displayName eq 'ECB4 Govt Invite Group'").Id

# Add external Users
#$externalUserEmail = "<ExternalUserEmail>"

$ExternalRecipients = Import-Excel -Path './ECB4 Govt Invite Group 11 19 24.xlsx'

foreach ($ExternalRecipient in $ExternalRecipients) {
    $ExternalUserEmail = $ExternalRecipient.Email
    $ExternalUserDisplayName = $ExternalRecipient.Name

    # Check if the user already exists in your tenant
    $user = Get-MgUser -Filter "mail eq '$externalUserEmail'"

    # If the user does not exist, invite them
    if ($user -eq $null) {
        $invitation = New-MgInvitation -InvitedUserEmailAddress $externalUserEmail -InvitedUserDisplayName "$ExternalUserDisplayName" -SendInvitationMessage -InviteRedirectUrl 'http://myapps.microsoft.com/'
        $user = Get-MgUser -Filter "mail eq '$externalUserEmail'"
    }

    # Add the user to the group
    Add-MgGroupMember -GroupId $groupId -DirectoryObjectId $user.Id
}