# AWS EC2 roles for Automation

This document describes creating IAM roles to attach to EC2 instances to facilitate automating interaction with AWS services without the need for long term credentials like IAM Access Keys.

!!!Note
    This document is a "work in progress". These roles are configured for various functions within AWS. As we implement new functions we will update this document.

!!! Warning
    Any user who can log on to the server will have the permission assigned to the role attached to the EC2 instance. You should implement appropriate security to ensure only authorized users can log on to the instances.

## Policies Required for SEC Secret Manager

If your EC2 role will be required to query Secret Manager for the SES Credentials. Create the following policy:

- Name: SES_Read_Secret_Value
- Permission:
    - secretsmanager:GetSecretValue
- Resource:
    - ARN of the Secret

Policy JSON

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "secretsmanager:GetSecretValue",
      "Resource": "arn:aws:secretsmanager:us-east-1:268928949034:secret:SES_SMTP_User-eMXw5N"
    }
  ]
}
```

Once this policy is created it can be applied to any EC2 Role that needs to get the Secret value for the SES credentials.

If you are setting up a role that will read the SES secret from a different account you will need to grant access to the KMS key used to encrypt the secret.

Add a second statement to the the above policy.

- Permission
    - kms:Decrypt
    - kms:GenerateDataKey
    - kms:DescribeKey
- Resource
    - ARN of the KMS Key
  
Policy JSON

```json
{
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "kms:Decrypt",
                "kms:GenerateDataKey",
                "kms:DescribeKey"
            ],
            "Resource": "arn:aws:kms:us-east-1:268928949034:key/18403968-b044-4ad2-8b21-fd20ec9f91f5"
        }
    ]
}
```


## SQL Server Copy Backups to S3

This describes creating a role for SQL Servers where a script copies backup files to AWS S3.

### Create Policy SQL2AWS_Backups

Create the following policy:

- Name: SQL2AWS_Backup
- Permissions:
    - s3:PutObject
    - s3:GetObjectAcl
    - s3:GetObject
    - s3:ListBucket
    - s3:GetBucketAcl
    - s3:PutObjectAcl
- Resources:
  - "arn:aws:s3:::bb-sql-backups/*"
  - "arn:aws:s3:::bb-sql-backups"

Policy JSON

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Sid": "VisualEditor0",
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObjectAcl",
                "s3:GetObject",
                "s3:ListBucket",
                "s3:GetBucketAcl",
                "s3:PutObjectAcl"
            ],
            "Resource": [
                "arn:aws:s3:::bb-sql-backups/*",
                "arn:aws:s3:::bb-sql-backups"
            ]
        }
    ]
}
```

### Create the Role

Create the following role:

- Name: EC2_SQL_Servers
- Trusted entity Type: AWS Service:EC2
- Policies:
    - SQL2AWS_Backups
    - SES_Read_Secret_Value

!!! Note
    You must select the Trusted entity type "AWS Service" and select "EC2" when creating the role or the role will not be selectable in the next step.

### Attach the Policy to the EC2 Instance

In the AWS EC2 console click the check box to the left of the intended instance.
Click the Action menu and select Security > Modify IAM Role.
From the IAM drop down, select EC2_SQL_Server.
Then click Update IAM role.

If additional permissions to AWS services are required in the future create new policies and attach them to this role.
