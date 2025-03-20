![Balfour Logo](https://www.balfourbeattyus.com/Balfour-dev.allata.com/media/content-media/2017-Balfour-Beatty-Logo-Blue.svg?ext=.svg)

# Windows Process Monitoring on a Zabbix Host

To monitor windows processes for CPU and Memory utilization you can use the process monitoring scripts and templates along with custom items to monitor specific processes.

## Templates

There are 2 specific templates you can use to monitor processes.

### Template Top Processes (active)

This template creates 2 items named 'Top Processes By CPU' and 'Top Processes by Memory'. These processes query the host and return the top 10 processes by either CPU utilization and memory utilization. This data is returned as an HTML data set that can be displayed on a Zabbix Dashboard.

To display this data on a dashboard, create a widget, select type 'Plain Text', select the host and the item (either top processes by CPU or Top Processes by Memory), set Number of lines to 1 (display 1 dataset), and check 'Show as HTML'

To display more or less than 10 process, clone the item, change the name amd modify the item key and change to number of processes returned.
Example: TopProcesses[20,CPU]

The client must be configured to execute Active checks.

These items utilize the TopProcesses.ps1 powerShell script. This script must be in the C:\zabbix\bin folder.

This script can be downloaded from the zabbix/bin folder in the [Staging Share](file//\\awsfsxe1file/Staging).

Modify the zabbix_agentd.conf file. This file should be in the c:\zabbix folder (some host may have it in the root of C:)

Scroll down the the UserParameter section of the file and add the following lines.

```bash
#User parameter to get top Processes
UserParameter=TopProcesses[*],powershell.exe -NonInteractive -NoLogo -NoProfile -ExecutionPolicy ByPass -File "C:\zabbix\bin\TopProcesses.ps1" -Top "$1" -Status "$2
```

You can also copy this setting from the config file located in the zabbix/bin folder in the [Staging Share](file//\\awsfsxe1file/Staging).

### Template Sophos Server Protect

This template monitors specific Sophos processes for CPU and Memory Utilization. This Template Targets the latest version of the Sophos Server Protect client.

This template has triggers for each item, these trigger have a severity if Warning. CPU triggers are set to >= 25% and Memory triggers are set to >= 100 MB.

The client must be configured to execute Active checks.

These items utilize the Get-ProcessStatus.ps1 PowerShell script. This script must be in the C:\zabbix\bin folder.

This script can be downloaded from the zabbix/bin folder in the [Staging Share](file//\\awsfsxe1file/Staging).

Modify the zabbix_agentd.conf file. This file should be in the c:\zabbix folder (some host may have it in the root of C:\)

Scroll down the the UserParameter section of the file and add the following lines.

```bash
#User parameter to get process statistics
UserParameter=ProcessStatus[*],powershell.exe -NonInteractive -NoLogo -NoProfile -ExecutionPolicy ByPass -File "C:\zabbix\bin\Get-ProcessStatus.ps1" -ProcessName "$1" -Status "$2"
```

You can also copy this setting from the config file located in the zabbix/bin folder in the [Staging Share](file//\\awsfsxe1file/Staging).

Once this is done, restart the 'Zabbix Agent' Service.

### Monitoring a Specific Process

You can monitor a specific process for CPU of Memory utilization by creating a custom Item and Trigger.

First make sure the Get-ProcessStatus.ps1 PowerShell script is in the c:/zabbix/bin folder and the ProcessStatus User Parameter is configured in the Zabbix_agent.conf file.

To Create an item, select the host you want to add the item to, select Items, then click the Create Item button in the upper right corner.

Fill in the following fields:

- Name: Enter a descriptive name.
- Type: Select Zabbix agent (active)
- Key: Enter 'ProcessName[{ProcessName},{Status}]' where {ProcessName} is the - name of the Windows Process and Status is either CPU or Memory.
- Units: For Memory enter KB, for CPU leave blank.
- Update Interval: This can be left at the default 1m for 1 minute.
- Custom intervals: No change
- History storage period: No change
- Trend storage period: No change
- Show value: No change
- New application: If the Processes application is not listed under Applications, enter Processes.
- Application: Select Processes
- Populate host inventory field: No change
- Description: Enter a description for this item (optional)
- Enabled: checked

Click Add to create the new item.

To create a trigger for an Item, Click on Triggers, then click New Trigger in the upper right corner.

Fill in the following fields:

- Name: Enter a descriptive name. The best way is to copy the Item name and append the purpose of the trigger. i.e. 'CPU Utilization Greater Than 50%'
- Operational Data: Optional
- Severity: Select the severity of the trigger. Severity of High or Disaster will generate Alert messages.
- Expression: Click Add
  - Item: Select the Item for this trigger 
  - Function: Leave as 'last() - Last (most recent) T value'
  - Last of (T): 1
  - Time shift: blank
  - Results: Set appropriately. i.e. >= 50.
- Leave all other fields as default, enter a description if desired. Leave enabled checked.

Click Add to save the trigger.
