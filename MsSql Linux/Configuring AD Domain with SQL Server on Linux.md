# Configuring an AD domain with MSSQL on Linux

This project will create an Active Directory Domain using a Linux server for the domain controller.
We will also create an MS SQL server on linux and configure Windows Authentication on the SQL Server.

## Part 1: Setting up the Domain

### Prerequisites

    - Operating System: Ubuntu 22.04 Server
    -  HostName: cwlan-dc1 (replace all instances of this with your name)
    -  IP Address: 10.0.0.205 (replace with your IP)
    -  FQDN: cwlan-dc1.cwlan.local

### Preparing the Domain Controller

#### Setup the host file

After installing the OS we need to modify a few thing.

Set the host name

```bash
sudo hostnamectl hostname cwlan-dc1
```

Edit the host file:

```bash
    sudo nano /etc/hosts
```

If there is the following listing in the host name, remove it.

```bash
127.0.0.0 cwlan-dc1
```

Now add the following:

```bash
    10.0.0.205 cwlan-dc1.cwlan.local cwlan.local
```

Save the host file.

#### Confirm the HOstname and FQDN resolution

```bash
# verify the host name
hostname -A

# carify FQDN resolves to your server IP
ping -c3 cwlan-dc1.cwlan.local
```

#### Disable th Network Name Resolution Service

Ubuntu has a service called systemd-resolved, which takes care of the DNS resolution requests. This service is unsuitable for Samba, and you must disable it and manually configure the DNS resolver instead.

1. Disable the systemd-resolved service by running the command below.
    
    ```bash
    sudo systemctl disable --now systemd-resolved
    ```

2. Next, remove the symbolic link to the file /etc/resolv.conf.

    ```bash
    sudo unlink /etc/resolv.conf
    ```

3. Create a new /etc/resolv.conf file.

    ```bash
    sudo name /etc/resolv.conf
    ```

4. Populate the /etc/resolv.conf file with the following information. Replace 10.0.0.205 with your server’s IP address and oji.com with your domain. Leave the nameserver 1.1.1.1 as the fallback DNS resolver, which is the public DNS resolver by Cloudflare.

    ```bash
    # Your Samba Domain Controller IP
    nameserver 10.0.0.205

    # Fallback resolver
    nameserver 1.1.1.1

    # Your samba domain
    search cwlan.local
    ```

5. Save the file.


### Installing Samba

After completing the server preparation, it is time to install Samba and other required packages to provision the domain controller.

1. First, ensure that the repository cache is up to date by running the below command.

    ```bash
    sudo apt update
    ```

2. Run the command below to install the required packages for a fully functioning domain controller.

    ```bash
    sudo apt install -y acl attr samba samba-dsdb-modules samba-vfs-modules smbclient winbind libpam-winbind libnss-winbind libpam-krb5 krb5-config krb5-user dnsutils chrony net-tools
    ```

3. On 'Configure Kerberos Authentication' 
   1. For Default Kerberos version 5 realm enter your domain name. Example: CWLAN.LOCAL
   2. For Kerberos servers for your realm enter your server name. Example: cwlan-dc1
   3. For Administrative server for your Kerberos realm enter your server name. Example cwlan-dc1

4. After everything is installed, disable any unnecessary services.

    ```bash
    suudo systemctl disable --now smbd nmbd winbind
    ```

5. Enable and activate the samba-ad-dc service. This service is what Samba needs to act as an Active Directory domain controller Linux server.

    ```bash
    # unmask the samba-ad-dc service
    sudo systemctl unmask samba-ad-dc

    # enable samba-ad-dc service
    sudo systemctl enable samba-ad-dc
    ```

### Provision the Domain Controller Linuc Server

Using the samba-tool binary, you can now provision the domain controller upon your Samba installation. Samba-tool is a configuration tool to interact with and configure various aspects of a Samba-based AD.

1. For good measure, backup the existing /etc/samba/smb.conf and /etc/krb5.conf files.

2. Run the below command to promote the Samba to an Active Directory domain controller Linux server.
   1. The –use-rfc2307 switch enables the Network Information Service (NIS) extension, which allows the DC to manage UNIX-based user accounts appropriately.

    ```bash
    sudo samba-tools domain provision --use-rfc2301 --interactive
    ``` 

3. Answer the prompts as follows:
   1. **Realm** - the tool automatically detects your Kerberos realm. In this example, the realm is **CWLAN.LOCAL**. Press Enter to accept the default.
   2. **Domain** – the tool automatically detects the NetBIOS domain name. In this example, the NetBIOS is **CWLAN**. Press Enter to continue.
   3. **DNS backend** – the default is **SAMBA_INTERNAL**. Press Enter to accept the default.
   4. **DNS forwarder IP address** – type the fallback resolver address you specified in resolve.conf earlier, which is **1.1.1.1**. Press Enter to continue.
   5. **Administrator password** – set the password of the default domain administrator. The password you specify must meet Microsoft’s minimum complexity requirements. Press Enter to proceed. Retype the password and press enter.

4. The samba-tool command generated the Samba AD Kerberos configuration file at /var/lib/samba/private/krb5.conf. You must copy this file to /etc/krb5.conf. To do so, run the following command.

    ```bash
    sudo cp -v /var/lib/samba/private/krb5.conf /etc/krb5.conf
    ```

5. Finally, start the samba-ad-sc service.

    ```bash
    sudo systemctl start samba-ad-dc
    ```

#### Testing the Domain Controller Linux Server

The Samba AD DC server is now running. In this section, you will perform a few post-installation tests to confirm key components are functioning as desired. One such test is to attempt logging into the default network shares on the DC.

Run the smbclient command to log on as the default administrator account and list (ls) the contents of the netlogon share.

```bash
smbclient //localhost/netlogon -U Administrator -c 'ls'
```

Enter the default admin password. The share should be accessible without errors if the DC is in a good state. As you can see below, the command listed the netlogon share directory.

```bash
cwilliamslocal@cwlan-dc1:~$ smbclient //localhost/netlogon -U Administrator -c 'ls'
Password for [CWLAN\Administrator]:
  .                                   D        0  Thu Nov 30 19:40:10 2023
  ..                                  D        0  Thu Nov 30 19:40:16 2023

		11758760 blocks of size 1024. 5613888 blocks available
```

#### Verify DNS Resolution for key Domain Records

Run the commands below to look up the following DNS records.

- TCP-based LDAP SRV record for the domain.
- UDP-based Kerberos SRV record for the domain.
- A record of the domain controller.

```bash
host -t SRV _ldap._tcp.cwlan.local
host -t SRV _kerberos._udp.cwlan.local
host -t A cwlan-dc1.cwlan.local
```

Each command should return the following results, indicating that the DNS resolution works.

```bash
cwilliamslocal@cwlan-dc1:~$ host -t SRV _ldap._tcp.cwlan.local;
host -t SRV _kerberos._udp.cwlan.local;
host -t A cwlan-dc1.cwlan.local
_ldap._tcp.cwlan.local has SRV record 0 100 389 cwlan-dc1.cwlan.local.
_kerberos._udp.cwlan.local has SRV record 0 100 88 cwlan-dc1.cwlan.local.
cwlan-dc1.cwlan.local has address 10.0.0.205
```

#### Testing Kerberos

The last test is to attempt to issue a Kerberos ticket successfully.

1. Execute the kinit command for the administrator user. The command automatically appends the realm to the user account. For example, the administrator will become administrator@OJI.com, where OJI.com is the realm.

    ```bash
    kinit administrator
    ``````

2. Type the administrator password on the prompt and press Enter. If the password is correct, you’ll see a Warning message about the password expiration, as shown below. You should see a message that the Administrators password will expire in 41 days.

3. Run the klist command below to list all tickets in the ticket cache.

    ```bash
    cwilliamslocal@cwlan-dc1:~$ klist
    Ticket cache: FILE:/tmp/krb5cc_1000
    Default principal: Administrator@CWLAN.LOCAL

    Valid starting       Expires              Service principal
    12/01/2023 23:56:03  12/02/2023 09:56:03  krbtgt/CWLAN.LOCAL@CWLAN.LOCAL
	    renew until 12/02/2023 23:55:57
    ```

### Domain Controller Conclusion

If all went well you domain controller is now up and running.

## Creating Users and Groups

At this point, if you have a windows computer or VM you can join it to your domain and install Remote Server Administration Tools and administer your domain.

On the DC you can use the samba-tool utility to great user and groups.

To create a user:

```bash
sudo samba-tool user create jane passwordForJane1
```

To create a group:

```bash
sudo samba-tool user create accounting
```

To add member to a group use:

```bash
sudo samba-tool group addmembers accounting jane,joe
```

The man page for Samba-tool has many more options.

## Configure MSSQL Server for Windows Authentication

Follow the instruction [Here](https://learn.microsoft.com/en-us/azure/azure-sql/virtual-machines/linux/sql-server-on-linux-vm-what-is-iaas-overview?view=azuresql) to install MSSQL server on your flavor of Linux.

Once SQL server in installed and working, go into Active Directory and create a user account for SQL server. i.e. mssql_svc.

### Create the Service Principal Names
There are many examples of how to do this on the internet. Most of them are probably valid. This is my personal preference as it has consistently worked for me.

The service principal name consists of MSSQLSvc/{Host FQDN or NetBIO name}:{port}

The key is to create all possible condition that might be used.

So, if our SQL Server's FQDN is cwlan-mssql1.cwlan.local we want to create 4 SPN.
- MSSQLSvc/cwlan-mssql1.cwlan.local
- MSSQLSvc/cwlan-mssql1.cwlan.local:1433
- MSSQLSvc/cwlan-mssql
- MSSQLSvc/cwlan-mssql:1433

In Windows we do this with:

```powershell
setspn -A MSSQLSvc/cwlan-mssql1.cwlan.local mssql_svc
setspn -A MSSQLSvc/cwlan-mssql.cwlan.local:1433 mssql_svc
setspn -A MSSQLSvc/cwlan-mssql mssql_svc
setspn -A MSSQLSvc/cwlan-mssql:1433 mssql_svc
```

In linux you need to do this logged into your Samba DC and use samba-tool.

```bash
sudo samba-tool spn add MSSQLSvc/cwlan-mssql1.cwlan.local mssql_svc
sudo samba-tool spn add MSSQLSvc/cwlan-mssql.cwlan.local:1433 mssql_svc
sudo samba-tool spn add MSSQLSvc/cwlan-mssql mssql_svc
sudo samba-tool spn add MSSQLSvc/cwlan-mssql:1433 mssql_svc
```

You can check your SPNs in linux with:

```bash
sudo samba-tool spn list mssql_svc
```

### Creating the keytab file for SQL Server Service

This is the most important piece, if you get this wrong it will not work.

#### Set the Cipher quite fit the user

It is important that all the cipher suites are assigned to the user. If you are using a Windows Domain Controller this is most likely taken care of for you.

On Linux you must set the newer aes256 ciphers. These are not set by default and if you skip this step the keytab file will not work.

1. Log in to your Samba domain controller.
2. Change to root.
   ```bash
   sudo su -
   ```
3. Authenticate to Kerberos as the Domain Administrator (or a user who is a member of the Domain Admins Group)
    ```bash
    kinit Administrator
    ```
4. Execute the following commmand:
   ```bash
   net ads enctypes set mssql_svc
   ```
5. It should produce output like this"
    ```bash
    'mssql_svc' uses "msDS-SupportedEncryptionTypes": 31 (0x0000001f)
    [ ] 0x00000001 DES-CBC-CRC
    [ ] 0x00000002 DES-CBC-MD5
    [X] 0x00000004 RC4-HMAC
    [X] 0x00000008 AES128-CTS-HMAC-SHA1-96
    [X] 0x00000010 AES256-CTS-HMAC-SHA1-96
    ```

    The last two are the most important.

#### Create the keytab file

In Windows we must check the Key Version Number. Usually it is 2 but we need to make sure.

In the following command the Domain name must be capitalized.

```bash
kinit mssql_svc@CWLAN.LOCAL
kvno mssql_svc@CWLAN.LOCAL
kvno MSSQLSvc/cwlan-mssql1.cwlan.local:1433@CWLAN.LOCAL
```

Add the Keytab entries using ktpass. Each line will append to the KeyTab file. Then password should be the password yo set for the service account.

```powershell
ktpass /princ MSSQLSvc/cwlan-mssql1.cwlan.local:1433@CWLAN.LOCAL /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser CWLAN.LOCAL\MSSQL_SVC /out mssql.keytab -setpass -setupn /kvno 2 /pass <StrongPassword>

ktpass /princ MSSQLSvc/cwlan-mssql1.cwlan.local:1433@CWLAN.LOCAL /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser CWLAN\mssql_svc /in mssql.keytab /out mssql.keytab -setpass -setupn /kvno 2 /pass <StrongPassword>

ktpass /princ MSSQLSvc/cwlan-mssql1:1433@CWLAN.LOCAL /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser CWLAN\mssql_svc /in mssql.keytab /out mssql.keytab -setpass -setupn /kvno 2 /pass <StrongPassword>

ktpass /princ MSSQLSvc/cwlan-mssql:1433@CWLAN.LOCAL /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser <DomainName>\<UserName> /in mssql.keytab /out mssql.keytab -setpass -setupn /kvno 2 /pass <StrongPassword>

ktpass /princ MSSQLSvc/cwlan-mssql1.cwlan.local@CWLAN.LOCAL /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser CWLAN.LOCAL\MSSQL_SVC /out mssql.keytab -setpass -setupn /kvno 2 /pass <StrongPassword>

ktpass /princ MSSQLSvc/cwlan-mssql1.cwlan.local@CWLAN.LOCAL /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser CWLAN\mssql_svc /in mssql.keytab /out mssql.keytab -setpass -setupn /kvno 2 /pass <StrongPassword>

ktpass /princ MSSQLSvc/cwlan-mssql1@CWLAN.LOCAL /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser CWLAN\mssql_svc /in mssql.keytab /out mssql.keytab -setpass -setupn /kvno 2 /pass <StrongPassword>

ktpass /princ MSSQLSvc/cwlan-mssql@CWLAN.LOCAL /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser <DomainName>\<UserName> /in mssql.keytab /out mssql.keytab -setpass -setupn /kvno 2 /pass <StrongPassword>

ktpass /princ mssql_svc@CWLAN.LOCAL /ptype KRB5_NT_PRINCIPAL /crypto aes256-sha1 /mapuser CWLAN\mssql_svc /in mssql.keytab /out mssql.keytab -setpass -setupn /kvno 2 /pass <StrongPassword>

ktpass /princ CWLAN@CWLAN.LOCAL /ptype KRB5_NT_PRINCIPAL /crypto rc4-hmac-nt /mapuser CWLAN\mssql_svc /in mssql.keytab /out mssql.keytab -setpass -setupn /kvno 2 /pass <StrongPassword>
```

On a Samba Domain controller it is a bit easier as the samba-tool does most of the work for you.

First export the keytabs entries for the user account.

```bash
sudo samba-tool domain exportkeytab mssql.keytab --principal mssql_svc
```

Now export the keytabs for the SPNa.

```bash
sudo samba-tool domain exportkeytab mssql.keytab --principal MSSQLSvc/cwlan-mssql1.cwlan.local 
sudo samba-tool domain exportkeytab mssql.keytab --principal MSSQLSvc/cwlan-mssql.cwlan.local:1433 
sudo samba-tool domain exportkeytab mssql.keytab --principal MSSQLSvc/cwlan-mssql
sudo samba-tool somain exportkeytab mssql.keytab --principal MSSQLSvc/cwlan-mssql:1433
```

Now examine the keytab file for accuracy.

```bash
klist -ket mssql.keytab
```

You shoud see something like this.

```bash
cwilliamslocal@cwlan-dc1:~$ sudo klist -ket mssql.keytab 
[sudo] password for cwilliamslocal: 
Keytab name: FILE:mssql.keytab
KVNO Timestamp           Principal
---- ------------------- ------------------------------------------------------
   2 12/04/2023 20:33:05 mssql_svc@CWLAN.LOCAL (aes256-cts-hmac-sha1-96) 
   2 12/04/2023 20:33:05 mssql_svc@CWLAN.LOCAL (aes128-cts-hmac-sha1-96) 
   2 12/04/2023 20:33:05 mssql_svc@CWLAN.LOCAL (DEPRECATED:arcfour-hmac) 
   2 12/04/2023 20:33:43 MSSQLSvc/cwlan-mssql1@CWLAN.LOCAL (aes256-cts-hmac-sha1-96) 
   2 12/04/2023 20:33:43 MSSQLSvc/cwlan-mssql1@CWLAN.LOCAL (aes128-cts-hmac-sha1-96) 
   2 12/04/2023 20:33:43 MSSQLSvc/cwlan-mssql1@CWLAN.LOCAL (DEPRECATED:arcfour-hmac) 
   2 12/04/2023 20:33:57 MSSQLSvc/cwlan-mssql1:1433@CWLAN.LOCAL (aes256-cts-hmac-sha1-96) 
   2 12/04/2023 20:33:57 MSSQLSvc/cwlan-mssql1:1433@CWLAN.LOCAL (aes128-cts-hmac-sha1-96) 
   2 12/04/2023 20:33:57 MSSQLSvc/cwlan-mssql1:1433@CWLAN.LOCAL (DEPRECATED:arcfour-hmac) 
   2 12/04/2023 20:34:10 MSSQLSvc/cwlan-mssql1.cwlan.local@CWLAN.LOCAL (aes256-cts-hmac-sha1-96) 
   2 12/04/2023 20:34:10 MSSQLSvc/cwlan-mssql1.cwlan.local@CWLAN.LOCAL (aes128-cts-hmac-sha1-96) 
   2 12/04/2023 20:34:10 MSSQLSvc/cwlan-mssql1.cwlan.local@CWLAN.LOCAL (DEPRECATED:arcfour-hmac) 
   2 12/04/2023 20:34:21 MSSQLSvc/cwlan-mssql1.cwlan.local:1433@CWLAN.LOCAL (aes256-cts-hmac-sha1-96) 
   2 12/04/2023 20:34:21 MSSQLSvc/cwlan-mssql1.cwlan.local:1433@CWLAN.LOCAL (aes128-cts-hmac-sha1-96) 
   2 12/04/2023 20:34:21 MSSQLSvc/cwlan-mssql1.cwlan.local:1433@CWLAN.LOCAL (DEPRECATED:arcfour-hmac) 
```

If you don't see all the ciphers then you did something wrong. Delete the keytab file and start over.

### Assign the Service Account user and the keytab file to SQL Server

If your SQL Server in a virtual machine it is highly recommended that yuo take a snaoshot before proceeding. This way of something goes wrong you can restore the snapshot and try again.

1. Copy the keytab file to your MSSQL Server. Place the file in /var/opt/mssql/secrets
2. Secure the Keytab file.
    ```bash
    sudo chown mssql:mssql /var/opt/mssql/secrets/mssql.keytab
    sudo chmod 400 /var/opt/mssql/secrets/mssql.keytab
    ```
3. Set the Privileged account for SQL server.(See below how to add the patnhj for the mssql-conf tool*)
    ```bash
    sudo mssql-conf set network.privilegedadaccount mssql_svc
    ```
4. Set the Key Tab for the SQL Server service
   ```bash
   sudo mssql-conf set network.kerberoskeytabfile /var/opt/mssql/secrets/mssql.keytab
   ```
5. Restart the SQL Server service and verify it is running.
   ```bash
   sudo systemctl restart mssql-server
   sudo systemctl status mssql-server
   ```

If th server starts you test you configuration.

### Testing Domain Authentication

Make sure you are logged into the computer you are testing from as you Domain Account.

Log on to your SQL server SQL as the 'sa' account with either Server Management Studio on Windows or Azure Data Studio (with preview features) from Linux.

Create a new Logon from your Active Directory account.

In Azure Data Studio you cannot browse AD so you have to type it in. Make sure you type the domain part of the user name in lower case. i.e. cwlan\myuser. If you type the domain in upper case the login will fail.

Grant the new user the sysadmin server role. Save the user.

Create a new connection and specify Windows Authentication.

If the connection succeeds, you have done this successfully.

Possible errors:
1. The login was from an untrusted domain
   1. You keytab file is incoorect. You are either missing ciphers or have a missing or incorrect SPN.
2. The login failed for user DOMAIN\Administrator. i.e. CWADMIN\Administrator
   1. You are not logged into the computer with an AD account that has a cooresponding SQL Login.
   2. You incorrectly types the username in Azure data studio. Either you misspelled the name or types the Domain portion in caps. Delete the SQL login and recreate.

## SQL Server Conclusion

This can be a challenging task to get right. There are many steps that all need to be done presicely and many opporunities to make a mistake. 

If you succeed, you now have an MS SQL Server rinning on an inexpensive operating system with minimal overhead and still have to primary advantage of MS SQL server. Active Directory Authentication.

`*` Setting the path for the mssql-conf tool.

The best way to do this is to set this in the secure path that is use by sudo. This way this tool is not availabel for other user who do not have sudo rights. (Though realy, no one else should be logging onto your SQL Server!)

1. Execute the following command.

   ```bash
   sudo visudo
   ```

2. Append the path \var\opt\mssql\bin to the line in the sudoers file that start with:
   
    ```bash
    Defaults        secure_path=
    ```

3. Save the file.

