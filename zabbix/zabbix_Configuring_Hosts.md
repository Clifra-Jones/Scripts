![Balfour Logo](https://www.balfourbeattyus.com/Balfour-dev.allata.com/media/content-media/2017-Balfour-Beatty-Logo-Blue.svg?ext=.svg)

# Configuring a Host in the Zabbix Server

For the Zabbix server to monitor a client server it must be configured as a 'host' in the Zabbix server.

## Discovery

### Discovery rules

Discovery can be done through many network protocols such as ICMP, FTP, HTTP, SSH, etc. Most often Discovery is done via ICMP ping.

Discovery is done through a Discovery Rule.

To create a discovery rule go to Configuration->Discovery.

Discovery Rules are configured with the following settings.

- **Name**

    The Name of the rule.

- **Discovery by proxy**

    If you are using Zabbix Proxies select the proxy server, otherwise select 'No Proxy'.

- **IP range**

    The IP range to use. This is entered as X.X.X.X-X or CIDR format X.X.X.X/XX

- **Update interval**

    The interval between each discovery run. Default is 4 hours. Entered as a Zabbix time reference. i.e. 4h.
    It is not recommended to have short intervals as that will increase the load on the Zabbix server.

- **Check**

    Add the protocol to be used for the check. You can add multiple protocols. All must return true.

- **Device uniqueness criteria**

    Defaults to IP Address

- **Hostname**

    Can be either DNS name or IP address

- **Visible Name**

    This is the name that appears in the Zabbix dashboard. Can be either Hostname, DNS Name or IP address

- **Enabled**

    Checked if the rule is enabled.

By default when a host is discovered it is added to the 'Discovered devices' list. To add the host to host groups or to configure templates you must create a Discovery Action.

### Discovery Actions

Discovery Actions perform specific tasks when a host is discovered by a Discovery rule. For example:

- **Add host**

    Adds the host to Zabbix.

- **Add to host groups**

    Adds the host to specific groups.

- **Link to templates**

    Link the host to the specified templates.

To create a Discovery Rule go to Configuration->Actions, click on the drop down in the upper right and select 'Discovery actions'

Under Action, configure the properties.

- **Name**

    The name of the action. This should be related to the Discovery Rule this action will be associated with.

- **Type of calculation**

    This can be 'And/Or', 'And', 'Or' or 'Custom'. For most uses 'And/Or' is sufficient.

- **Condition**

    The Conditions used to determine if the action should be performed. For most situations this should be set to:

  * Discovery rule equals {*the name of the discovery rule*}
  * Discovery status is *Up*

- **Enabled**

    Checked if the Action is Enabled.

Now we create the Operations that will be performed if the Action conditions are met.

Click on the Operations tab and configure the settings.

Under Operations click **Add**, then add then select the operations to be performed. For most Discoveries you will use:

- **Add Host**

    This add the host to Zabbix.

- **Add to Host groups**
 
    Select the host groups to add the host to. You can add the host to multiple groups. The Groups must already exist.

- **Link to template**

    Select the templates to link the host to. At a minimum you should link the host to the 'Template Module ICMP Ping' template.

Click Update to save the action.

!!! Note
    You can monitor Discovery Rules by going to Monitoring-> Discovery and selecting the Discovery Rule. Discovered hosts wil appear in the 'Discovered devices' list.

!!! Note
    If the DNS name for a server does not appear in the 'Discovered devices' list this means that a reverse DNS entry (pointer record) does not exist for this host. You should investigate and correct this problem on your DNS server so that future discovered hosts are correct.

## Host Configuration

Once the host is discovered it can be configure to its specific needs.

Go to Configuration->Hosts and find the host to configure. Click on the host name.

!!! Note
    If you added the host to a host group during discovery you can filter the list by that host group.

Verify the DNS name is correct and under Interfaces change 'Connect to' to DNS.

!!! Note
    Connecting by DNS name is preferred for servers. Devices that may not have a DNS name such as switches, routers and security devices can connect to IP address.


Under Groups add any appropriate groups this server should belong to.

For Windows servers add the host to the 'Windows Servers' group then go to Templates and add the template 'Template OS Windows by Zabbix Agent'.

For SQL servers add the following templates:

- Template Microsoft SQL Server DE Baseline
- Template Microsoft SQL Server SA Baseline

For SQL Server SSIS add the template:

- Template MS SQL Server SSIS

For Domain Controllers add the following templates:

- Template AD DS Health and Performance
- Template AD DS Monitoring and Attack Detection
- AD Audit

There are a variety of templates for other systems and application we will not cover here.

## Adding a Host without Discovery

Sometimes you need to configure a host that was not discovered.

To do this go to Configuration->Hosts, click Create Host in the top right corner. Fill in the following:

- **Host name**

    The DNS name of the host.

- **Visible name**

    The DNS name of the host.

- **Groups**

    Add to all appropriate groups.

- **Interfaces**

    Add the IP address and DNS name of the host. It is always best to change the 'Connect to' to DNS. (If this host is being monitored via SNMP you must add another interface specific to SNMP.)

- **Description**

    Add if appropriate.

- **Monitored by Proxy**
    Select the proxy server if appropriate or leave as 'no proxy'.

- **Enabled**
    Checked

Click on Templates and add any appropriate Templates, then click Add.
