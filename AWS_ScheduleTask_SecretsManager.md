![Balfour Logo](https://www.balfourbeattyus.com/Balfour-dev.allata.com/media/content-media/2017-Balfour-Beatty-Logo-Blue.svg?ext=.svg)

## Running a Scheduled Task with an IAM Account that uses Secrets Manager

AWS IAM Accounts use Access Keys to authenticate to AWS. This is very useful for unattended tasks that are run as Scheduled Tasks. Balfour Beatty rotates these Access Keys on a regular bases (90 days) for security reason. These new keys are stored in Secrets Manager.

The challenge with a Scheduled Task is once these keys are rotated and the old keys are inactivated the scheduled task can fail due to invalid keys. Updating the local user profile with the new keys manually can be a tedious task if Schedule Tasks are running on multiple servers. To prevent this we can automate the process of retrieving the keys from Secrets Manager and updating the local user profile.

This process requires 2 AWS Tools for PowerShell modules.

- AWS.Tools.IdentityManagement
- AWS.Tools.SecretsManager

The AWS CLI also needs to be installed on the computer.

The Balfour Beatty US IT Infrastructure Team assigns all IAM Accounts with Access Keys the Tag "SecretName". This name stores the secret name associated with the account. This tag value is usually the same as the account name. If the account is not in the primary Infrastructure AWS Account it is appended with an account identifier.

 !!! Note
    This IAM account must be granted permission to read it's own IAM account. This should be granted when the account is created by the IT Infrastructure team.

In the beginning of the script that your scheduled task runs we want to get the current Access Keys being used, then retrieve the Access Keys stored in Secrets Manager for this account and compare to see if they have changed.

!!! Note
    If you have many tasks using this IAM account on a server you can put these steps into a separate script/task that is scheduled to run prior to all you other scripts. Ths way these steps are only executed once per task schedule.

### Process to update the local profile

The task that will perform AWS operations needs to be run under a user account that has been configured for AWS Access Keys. This can either be a Domain account or a local account depending on other access requirements.

Log on to the account on the server that the task is running under (this can be done by opening a command windows as this user) and configure the AWS CLI with the current account's Access Keys. (You will need get the current account's Access Keys from the IT Infrastructure group.)

Execute the command below in a command window as the user that will run the scheduled tasks.

```bash
aws configure
```

You will be prompted for the AWS Access Key ID, the AWS Secret Access Key, the Default region name and the Default Output format.

Copy and paste in the Access Key ID and Secret Access Key provided by The IT Infrastructure team, enter the AWS region where the majority of your services run and leave Default output format to None.

Now we will create the script that will update this local profile with updated Access Keys when they are rotated.

The first thing we do in our script is to retrieve the credentials the script is running under. This is the Access Keys configured under our local user.

```powershell
$MyCreds = (Get-AWSCredentials -ProfileName 'default').GetCredentials()
```

There should only be one profile (the default profile) configured for this user but we specify the profile name 'default' just to be sure.

Next we get the IAM user object for this user from AWS. We wrap this in a try-catch block to catch if any errors occur.

```powershell
try {
    $myIamUser = Get-IAMUser
} catch {
    throw $_
}
```

We do not need to specify the IAM user's name as the default is to get the current user.

Now we need to retrieve the value of the SecretName tag from the IAM user object.

```powershell
$Tags = $myIamUser.Tags
$secretName = $Tags[$tags.Key.IndexOf("SecretName")].Value
```

Now that we have the secret name we can retrieve the Secret values stored in Secrets Manager for this IAM user. These values are stored in Secrets Manager as a JSON object so we must convert from JSON.

```powershell
$MySecretsAccessKeys = (Get-SECSecretValue -SecretId $secretName).SecretString | ConvertFrom-Json
```

Now we are going to compare the AccessKey property of the local credentials object to the AccessKeyId property of the Secrets value object. If they do not match this means that new Access Keys were created for this user and we need to update the local profile.

```powershell
if ($MyCreds.AccessKey -ne $MySecretAccessKeys.AccessKeyId) {
    # The access Key IDs don't match so now we update
    # the local stored credential file in the user's profile, 
    # then update the currently running credentials.
    
    # update the local profile.
    # We use forward slashes here to insure our script is cross
    # compatible with Windows and Linux.
    $profileLocation = "{0}/.aws/credentials" -f $home
    
    # Save the new values to the default profile.
    Set-AWSCredentials -AccessKey $MySecretsAccessKeys.AccessKeyID -SecretKey $MySecretsAccessKeys.SecretAccessKey -StoreAs 'default' -ProfileLocation $profileLocation

    # Now update the currently running profile.
    Set-AWSCredentials -profileName 'default'    
}
```

The reason we issue the Set-AWSCredential command twice is that under Windows the credentials are stored in 2 places, the local credential file under .aws/credentials and the .Net Framework's encrypted credential store. Issuing the command without the -ProfileLocation only updates the .Net Framework Credential store.

You've now updated your local access keys and can continue with your AWS operations knowing your access keys are up to date.