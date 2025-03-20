![Balfour Logo](https://www.balfourbeattyus.com/Balfour-dev.allata.com/media/content-media/2017-Balfour-Beatty-Logo-Blue.svg?ext=.svg)

# Installing and Configuring the Zabbix Agent on a Server

The Zabbix agent is a light weight service that communicates server health and statistics to the Zabbix server.
The Zabbix agent requires the following ports to be open on the client and server:

- TCP 10050 for passive checks
- TCP 10051 for active checks

If you are configuring a firewall or a cloud security group these ports should be restricted to the Zabbix server IP or security group.

## Installing the Agent

The agent files can be downloaded from \\\awsfsxe1file.bbc.local\Staging\zabbix, copy the entire zabbix folder to  C:\, so that you have a folder C:\zabbix.
Now, make sure file extensions are displayed in Explorer.
Edit the file c:\zabbix\zabbix_agentd.conf in notepad. Make the following changes.

```bash
LogFile=c:\zabbix\zabbix_agentd.log
```

Under the Passive checks related section

```bash
Server=zabbixciv #(or Server=zabbixciv.bbc.local if the server is in bbcgrp.local)
```

Under the Active Checks related section if active checks are being used.

```bash
Server=zabbixciv (or Server=zabbixciv.bbcgrp.local in the server is in bbcgrp.local)

Hostname={Hostname of this computer}
```

!!! Warning
    The hostname setting under Active Checks must match the host name configured in zabbix for the server you are installing the agent on exactly as it is configured in the Zabbix server!

Under the Option: UserParameter section configure any user parameters you requires. (See Below)

Save the file. (You may need to grant yourself modify permissions on the file to save it. This is a Windows server restriction)

## Installing the agent service

Open an elevated command prompt and change to the c:\zabbix folder.
Run the following command:

```bash
zabbix_agentd.exe -c c:\zabbix\zabbix_agentd.conf -i
```

This will install the agent service using the specified configuration file.
If there is a file c:\zabbix\zabbix_agentd.log file delete it.
Start the 'Zabbix Agent' service. Wait a few minutes and then open the agent log file and look for any errors.
If the agent is working fine you should see something like this.

```bash
  7764:20220509:095434.252 Starting Zabbix Agent [hqvsvsql02.bbcgrp.local]. Zabbix 5.0.1 (revision c2a0b03480).
  7764:20220509:095434.254 **** Enabled features ****
  7764:20220509:095434.255 IPv6 support:          YES
  7764:20220509:095434.257 TLS support:            NO
  7764:20220509:095434.258 **************************
  7764:20220509:095434.259 using configuration file: C:\zabbix\zabbix_agentd.conf
  7764:20220509:095435.164 agent #0 started [main process]
  3732:20220509:095435.165 agent #1 started [collector]
  6492:20220509:095435.166 agent #2 started [listener #1]
  3680:20220509:095435.167 agent #3 started [listener #2]
  7744:20220509:095435.168 agent #4 started [listener #3]
  7040:20220509:095435.168 agent #5 started [active checks #1]
```

## Active vs Passive checks

Passive checks are done by the Zabbix server sending a request over port 10050 to the agent asking for the latest data. There are no additional configurations needed on the client to configure passive checks.

Active checks are scripts that run on the client that send data to the Zabbix server. These scripts are usually created using PowerShell on Windows and using BASH Shell or PowerShell on Linux. Active check scripts will mostly return numeric or true/false data. Checks that are going to be used in alerts can only return numeric or true/false data. You can return text data to be used in Dashboard items but these cannot be used in alerts. Text data can be returned in either plain text, HTML or JSON format. You can also configure Active Checks to do Discovery that configures data for other checks.

To configure an active check you create a UserParameter in the zabbix_agent.conf file. The format is:

```bash
UserParameter={itemName},{script executable statement] {script parameters}
```

ItemName can be any text including - & .
The executable statement is the program that executes the script. i.e. powershell.exe.
The script parameters can be literal parameters or sent from the zabbix server. To specify parameters sent from the server use "$1", "$2" etc.

### SQL Server Active Checks

There are specific active checks for SQL servers. These are located in the c:\zabbix\bin folder.
The user parameter statement should already be in the configuration file, just un-comment any user parameters with '.mssql.' in the name.

### Activating Changes

When changes are made to the zabbix_agent.conf file you must restart the Zabbix Agent service for the changes to take effect.
