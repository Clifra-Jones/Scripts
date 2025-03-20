#!/usr/bin/python3

import sys
import boto3

# AWS credentials and region
# If the Zabbix server is running on AWS EC2 with the appropriate instance role you can 
# comment out the AWS_ACCESS_KEY and AWS_ACCESS_KEY variables.
#  
AWS_ACCESS_KEY = 'YOUR_AWS_ACCESS_KEY'
AWS_SECRET_KEY = 'YOUR_AWS_SECRET_KEY'
AWS_REGION = 'YOUR_AWS_REGION'

# SNS topic ARN
SNS_TOPIC_ARN = 'YOUR_SNS_TOPIC_ARN'

def send_to_sns(subject, message):
    try:
        #If you are running Zabbix in an AWS INstance with an instance role
        # uncomment the code below:
        #
        # sns = boto3.client('sns', region_name=AWS_REGION)
        #
        # then comment out the code below.
        sns = boto3.client('sns', 
                           aws_access_key_id=AWS_ACCESS_KEY,
                           aws_secret_access_key=AWS_SECRET_KEY,
                           region_name=AWS_REGION)
        
        response = sns.publish(
            TopicArn=SNS_TOPIC_ARN,
            Subject=subject,
            Message=message
        )
        print(f"Message sent to SNS. Message ID: {response['MessageId']}")
    except Exception as e:
        print(f"Error sending message to SNS: {str(e)}")

if __name__ == "__main__":
    if len(sys.argv) != 3:
        print("Usage: ./send_to_sns.py <subject> <message>")
        sys.exit(1)

    subject = sys.argv[1]
    message = sys.argv[2]
    send_to_sns(subject, message)