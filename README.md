# Terraform-aws-plays
The repo that I used while tryin to learn terraform via aws resources.


With this terraform code , you can find an example code for creation of resources listed below:
- aws instance
- aws iam role
- aws kinesis stream
- aws kinesis firehose delivery stream
- aws api gateway rest api
- aws api gateway resource 
- aws api gateway method
- aws api gateway intregration
- aws api gateway method response
- aws api gateway integration response
- aws s3 bucket
- aws s3 bucket versioning
- aws s3 bucket acl
- aws s3 bucket public access block
- aws sns topic
- aws sns topic subscription
- aws lambda function
- aws lambda permission

API GW --> Kinesis Stream --> Kinesis Firehose --> s3 Bucket
when you put any record through API GW, it triggers Kinesis Stream, and to be able to write the data to s3 Bucket, Kinesis Firehose is used in between.

$ terraform -version 
Terraform v1.1.7 on linux_arm64

provider registry.terraform.io/hashicorp/aws v4.8.0

example put record:
http put https://xfpsq6yqsg.execute-api.eu-central-1.amazonaws.com/test/streams/kinesis-stream/record Data="{'Type':'Vehicle','Voltage':12}" PartitionKey=1
