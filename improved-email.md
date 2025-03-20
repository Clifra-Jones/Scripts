# Announcement: New Development SQL Server with Enhanced Security Framework


We have implemented a dedicated development SQL server (AWSSQLDEV01) in the Dev-Ops AWS account. This strategic move separates our development and test databases from the production environment, enhancing both performance and security.

## What's New

- **Dedicated development server**: AWSSQLDEV01 now hosts copies of all necessary databases for your development work
- **Enhanced security framework**: Provides appropriate permissions while maintaining system integrity
- **More developer autonomy**: Reduces the need for frequent Infrastructure/DBA team involvement

## Database Availability

All relevant databases have been copied to AWSSQLDEV01. Please test your connectivity and access, then let me know if you need a final refresh from the previous server before a final cut-over.

## Security Framework Overview

Our new security model balances developer needs with security best practices:

### Server-Level Access

We're leveraging the SQL Server 2022 ##MS_DatabaseManager## role, which enables database creation permissions. The following team members have this access through the SQLServer_Database_Managers AD group:
- James Mcpherson
- Rob Laib

### Automatic Security Configuration

When databases are created, the following security measures are automatically configured:

1. **DB_PermissionManager role**
   - Assigned to SQLServer_Database_Managers group
   - Allows creating database users from existing logins
   - Enables user/role management within databases
   - Cannot create new server logins or modify server-level security

2. **db_admin_custom role**
   - Provides enhanced developer capabilities:
     - Schema modifications
     - Table/view/procedure/function creation and alteration
     - Object definition access
     - Data manipulation (select, insert, update, delete)
     - Stored procedure and function execution
   - Restrictions include:
     - Cannot drop database objects
     - Cannot modify database settings
     - Cannot manage database users or roles

### Best Practices

- We recommend using Active Directory groups for SQL authentication via SSMS
- Groups can be created for all databases or individual databases as needed
- The db_admin_custom role offers appropriate permissions for most development work

### Database Ownership (db_owner)

The db_owner role should be limited to individuals requiring elevated permissions (team managers or designated personnel). This role can:
- Modify object ownership
- Execute restricted system procedures
- Change database options
- Drop database objects

Database owners is set to the AD group SQLServer_Solutions_DB_Owners. Current membership is:
James McPherson
Rob Laib

To maintain security, db_owner membership will be regularly audited and reported.

## Getting Started

Please let me know if you need any assistance transitioning to the new server. This framework provides the flexibility you need while ensuring a secure and consistent environment.

Regards,
[Your Name]
