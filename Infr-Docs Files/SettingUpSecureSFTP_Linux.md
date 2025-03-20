# Creating and Configuring a Secure SFTP Server on Linux

## Prerequisites

In this example we are going to be using Rocky Linux 9.3. Rocky linux is the Community supported replacement for CentOS.
Rocky Linux is a like for like clone of RedHat Enterprise Linux.

It is assumed you have a base install of Rocky Linux 9 installed and can SSH into the server.

We are going to use openssh-server as our SFTP server. This should already be installed but to verify this type the following in the terminal.

```bash
sudo dnf install openssh-server
```

## User Setup

For each user who will connect to the SFTP server a Linux user account must be setup.

>Our examples are using generic users. You should create specific usernames for your users.

Create the user with the following command.

```bash
sudo adduser user01
```

Now set a password for the user.

```bash
sudo passwd user01
```

Repeat these steps for each user you are setting up.

If your users are only going to be allowed to access a folder exclusively assigned to them then this is all you need to do.

If your users are going to access a shared folder that multiple user will use, then you need to setup a group and assign the users to that group.

```bash
sudo groupadd sftpusers
```

Then add the user to the group.

```bash
sudo usermod -a -G sftpusers user01
```

Repeat this step for all your user.

## SFTP Folder Configuration

### Individual Folders

Each user will be jailed into a root folder  and have a folder that they can read and write files to, i.e. MyFiles.

>The user will not be abe to write files to the root of their folder. They can only add and read files from subfolders.

Create the user root folder.

```bash
sudo mkdir /var/sftp/user01
```

This folder must be owned by root.

```bash
sudo chown root:root /var/sftp/user01
```

Set the permission on this folder.

```bash
sudo chmod 755 /var/sftp/user01
```
>You cannot change the permission on this folder. Setting the permissions to anything other than 755 will cause problems.

Create a folder for the user to use.

```bash
sudo mkdir /var/sftp/user01/MyFiles
```

Set the owner of this folder to the user.

```bash
sudo chown user01:user01 /var/sftp/user01/MyFiles
```

Set permissions on the users folder.

```bash
sudo chmod 700 /var/sftp/user01/MyFiles
```

This sets owner full access (7), group no access (0), all others no access (0).

### Group Folders Only

Members of the sftpusers group will be placed in the group folder at logon. We will create 2 folders for them to upload and read files.

>Users will not be able to upload files to the root of the shared folder. Only to subfolders.

Create the shared folder.

```bash
sudo mkdir /var/sftp/shared
```

Set ownership of this folder to root.

```bash
sudo chown root:root /var/sftp/shared
```

Set the permission on the folder.

```bash
sudo chmod 755 /var/sftp/shared
```

Create subfolders for the groups files.

```bash
sudo mkdir /var/sftp/shared/Documents
sudo mkdir /var/sftp/shared/Picture
```

Set ownership and permissions on these folders.

```bash
sudo chown sftpusers:sftpusers /var/sftp/shared/*
sudo chmod 770 /var/sftp/shared/*
```

### Hybrid Configuration

In this configuration users will be placed in their user directory but will be allowed to change directory to the parent and then change directory to the 'shared' directory.

>Note: Users will see other users folders from the parent, they will be able to change directory to other folders but cannot read or write to those folders.

Make sure any user who needs access to the 'shared' folder is a member of the sftpusers group.

```bash
usermod -a -G sftpusers user01
```

In this configuration all users will have their root folder set to /var/sftp so we need to set root as the owner and set permissions properly

```bash
sudo chown root:root /var/sftp
sudo chmod 755 /var/sftp
```

Now we need to make each user the owner of their folders and set permissions.

```bash
sudo chown user01:user01 /var/sftp/user01
sudo chmod -R 700 /var/sftp/user01
```

>The -R option sets permissions recursively on all subfolders and files.

Now we set ownership and permissions on the shared folder

```bash
sudo chown sftpgroup:sftpgroup /var/sftp/shared
sudo chmod 770 /var/sftp/shared
```

## Open SSH Configuration

Here we are configuring openssh to only allow users to use SFTP and restricting them from using SSH to access the server and jailing to the designated folder.

>**Caution**: Before you start this process it is highly recommended you backup the /etc/ssh/sshd_config file. To do this do the following.

```bash
sudo cp /etc/ssh/sshd_config /etc/ssh/sshd_config.bak
```

We are going to use nano as our text editor. If you performed a minimal install of Rocky linux you will need to install it.

```bash
sudo dnf install nano
```

Edit the sshd_config file.

```bash
sudo nano /etc/ssh/sshd_config
```

Near the bottom of the file you will see this:

>#override default of no subsystem
Subsystem    &nbsp;&nbsp;&nbsp;sftp    &nbsp;&nbsp;&nbsp;/user/libexec/openssh/sftp-server

We want to change this to read:

>#override default of no subsystem
 #Subsystem &nbsp;&nbsp;&nbsp;sftp &nbsp;&nbsp;&nbsp;/user/libexec/openssh/sftp-server
 Subsystem &nbsp;&nbsp;&nbsp;sftp &nbsp;&nbsp;&nbsp;internal-sftp

 Save and exit the file. (ctrl-o, enter; ctrl-x)

 Now we are going to create configuration files specific to SFTP.

#### Individual User Folders

As stated above these users will be jailed into their user folders.

Create the following file.

```bash
sudo nano /etc/ssh/sshd_config.d/sftpusers.conf
```

In this file we want to add the following for each user:
>Match User user01
&nbsp;&nbsp;&nbsp;&nbsp;ChrootDirectory /var/sftp/user01
&nbsp;&nbsp;&nbsp;&nbsp;ForceCommand internal-sftp
&nbsp;&nbsp;&nbsp;&nbsp;AllowTCPForwarding no
&nbsp;&nbsp;&nbsp;&nbsp;X11Forwarding no

Add a section for each user.

Save this file.

#### Shared Group Only Folder

As stated above, users in this group will be jailed into the shared folder.

Create the following file.

```bash
sudo nano /etc/ssh/sshd_config.d/sftpgroup.conf
```

Create the following section:
>Match User sftpusers
&nbsp;&nbsp;&nbsp;&nbsp;ChrootDirectory /var/sftp/sftpshared
&nbsp;&nbsp;&nbsp;&nbsp;ForceCommand internal-sftp
&nbsp;&nbsp;&nbsp;&nbsp;AllowTCPForwarding no
&nbsp;&nbsp;&nbsp;&nbsp;X11Forwarding no

When finished, save and exit.

#### Hybrid User and Group Folders

As stated above users will have access to their personal folder as well as the shared folder. When they log in they will be placed in their user folder.

Create the following file.

```bash
sudo name /etc/ssh/sshd_config.d/sftphybrid.conf
```

For each user add a section as follows:
>Match User User01
&nbsp;&nbsp;&nbsp;&nbsp;ChrootDirectory /var/sftp/user01
&nbsp;&nbsp;&nbsp;&nbsp;ForceCommand internal-sftp -d /user01
&nbsp;&nbsp;&nbsp;&nbsp;AllowTCPForwarding no
&nbsp;&nbsp;&nbsp;&nbsp;X11Forwarding no

Save the file.

There is no need to add a section for the shared folder.

#### Linking your configuration files to the main SSHD configuration File

Now open the /etc/ssh/sshd_config file.

```bash
sudo nano /etc/ssh/sshd_config
```

Add a line to "include" the configuration file you want to use.

For jailed users.

>Include /etc/ssh/sshd_config.d/sftpuser.conf

For jailed groups.

>Include /etc/ssh/sshd_config.d/sftpgroup.conf

For Hybrid configuration.

>Include /etc/ssh/sshd_config.d/sftphybrid.conf

Save and exit.

>If you have Match statements already in your sshd_config file the Include statements MUST be BEFORE any Match statements.

You can include multiple files in your sshd_config file but you need to make sure you do not have conflicting Match statements for a user.

For example, if you have a match statement for a user and a group and the user is a member of the group, whichever statement is last in the config file will take effect.

To include multiple files with one statement, do the following:
>Include /etc/ssh/sshd_config.d/*.conf

Now restart the SSHD daemon to enable the new configuration.

```bash
sudo systemctl restart sshd
```


## Testing the configuration

First we are going to check that our user CANNOT use SSH to connect to the server.

Attempt to SSH to the server.

```bash
ssh user01@localhost
```

You should get the following response:
>This service allows sftp connections only.
Connection to localhost closed.

Now test logging in with sftp.

```bash
sftp User01@localhost
```

You should be logged in and jailed into the proper directory. You should test upload and download and make sure your user cannot access any directories they should not be able to.

If you get any other error message check the service's journal with:

```bash
sudo journalctl -u sshd | less
```

Press space bar to scroll to the last entries and check for errors.

If you see this error:
>fatal: bad ownership or modes for chroot directory component

Then the folder in the statement ChrootDirectory has incorrect permissions.

The folder MUST be owned by root and have 755 permissions.

## Conclusion

Now you have a properly secured and functional SFTP server running on a Linux OS.

If you are going to expose your new server to the Internet you should put a proper application firewall in front of your server and only allow port 22 (SSH) to flow through the firewall. If you are working with known clients you should restrict connections to be only allowed from their IP address/subnets. This will give you a properly secured and safe SFTP server.

## Appendix I - Configuring in AWS

By default AWS disallows password authentication to Linux instances over SSH. You will need to enable this if you want password authentication.

You will also need to enable this temporarily if you want to configure passwordless authentication with SSH Keys.

To do this, edit the sshd_config file.

```bash
sudo nano /etc/ssh/sshd_config
```

Scroll down to the line:
>PasswordAuthentication no

Change it to:
>PasswordAuthentication yes

Restart the SSHD service.

```bash
sudo systemctl restart sshd
```

You can now log in with a password.

## Appendix II - Password-less Authentication with SSH Keys

Password-less authentication allows the user to authenticate to the server with a public/private key pair. This is more secure than sending password over the Internet as the private key is never sent to the server.

You can either create individual key pairs for each user (more secure) or create a key pair that each user will use (less secure).

You must have the openssh client installed on a computer.

To create the key-pair we will use the ssh-keygen command.

To create a key-pair in the users profile on their computer we simply execute ssh-keygen.

```bash
ssh keygen
```

You will see the following output:
>Linux
Creating directory