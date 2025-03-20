![Balfour Logo](https://www.balfourbeattyus.com/Balfour-dev.allata.com/media/content-media/2017-Balfour-Beatty-Logo-Blue.svg?ext=.svg)

## Update SQL Server Database Mail credentials

Within Balfour Beatty SQL Server Database Mail uses AWS Simple Mail Service (SES) to send notification emails from SQL server.
Balfour Beatty rotates these SES credentials every 90 days. These Credentials are stored in AWS Secrets Manager.

The procedure below outlines how to automate the process of updating of these credentials on SQL servers. This is done by using a scheduled task that run a PowerShell script.

This script will require the following modules:

- SqlServer
- AWS.Tools.SecretsManager
- AWS.Tools.IdentityManagement (if you update the IAM access keys in this script)

!!! Note
    This process needs to run under a user account configure to use Access Keys assigned to an IAM user. These access keys will also rotate every 90 days. See the article [AWS Scheduled Task Secrets Manager](). You can either prepend the process outlined in ths article to your script or create a separate scheduled task that runs before this task. This account must also have access to the MSDB database either with specific rights of as a sysadmin. Keep the password for this account secure.

The first thing we must do is retrieve the current SES credentials from Secrets Manager.

```powershell
$ses_creds = (Get-SECSecretValue -SecretId 'SES_SMTP_User').SecretString | ConvertFrom-Json
```

Now we create 2 string variables containing the SQL scripts to interact with Database Mail.

```powershell
# This SQL script retrieves the current SQL Database Mail configurations
$sqlGetDbMailAccounts = "SELECT [sysmail_server].[account_id]
,[sysmail_account].[name] AS [AccountName]
,[servertype]
,[servername] AS [SMTPServerAddress]
,[Port]
,[Username]

FROM [msdb].[dbo].[sysmail_server]
INNER JOIN [msdb].[dbo].[sysmail_account]
ON [sysmail_server].[account_id]=[sysmail_account].[account_id]"

# this SQL script updates the Database Mail account for the Account Id.
$sqlUpdateDbMailAccount = "EXEC [dbo].[sysmail_update_account_sp] 
     @account_id='{0}'
    ,@username='{1}'
    ,@password='{2}'"
```

Now retrieve the Database Mail accounts from SQL Server.

```powershell
dbMailAccounts = Invoke-Sqlcmd -ServerInstance $sqlserver -Database msdb -Query $sqlGetDbMailAccounts
```

Now loop through each Database Mail account and compare the username to the SmtpUsername property retrieved from Secrets Manager. If the username has changed update the Database Mail account.

```powershell
foreach ($dbMailAccount in $dbMailAccounts) {
    If ($dbMailAccount.Username -ne $ses_creds.SmtpUsername) {
        try{
            $Procedure = $sqlUpdateDbMailAccount -f $dbMailAccount.account_Id, $ses_creds.SmtpUsername, $ses_creds.SmtpPassword
            $result = Invoke-Sqlcmd -ServerInstance $sqlserver -Database 'msdb' -Query $Procedure
        } catch {
            throw $result
        }
        $msg = "Database mail account {0} updated to new credentials." -f $dbMailAccount.AccountName
    }
}
```

You can configure the scheduled task to run once per day. If the credentials have not changed it will do nothing.