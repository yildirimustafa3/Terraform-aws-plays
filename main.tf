terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
      version = "4.8.0"
    }
  }
}

variable "myaccess_key" { # A variable stored in terraform.tfvars
}

variable "mysecret_key" { # A variable stored in terraform.tfvars
}


provider "aws" { # Configuring provider 
  # Configuration options
  region = "eu-central-1"
  access_key = var.myaccess_key
  secret_key = var.mysecret_key
}


resource "aws_instance" "mustafa" { #https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/instance
  ami           = "ami-0d527b8c289b4af7f" # ami-0d527b8c289b4af7f (64-bit x86) - Ubuntu Server 20.04 LTS - Franfurt(eu-central-1)
  instance_type = "t2.micro"

  tags = {
    Name = "HelloWorld"
  }
}



resource "aws_iam_role" "RoleForApigwterraform" { #https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
  name = "RoleForApigwterraform"
  description= "sapigwterraform desc"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "apigateway.amazonaws.com" # for API GW services
        }
      },
    ]
  })

  managed_policy_arns= [ #granted permissions that is being used by this role
              "arn:aws:iam::aws:policy/AmazonKinesisFullAccess",
              "arn:aws:iam::aws:policy/AmazonS3FullAccess",
              "arn:aws:iam::aws:policy/CloudWatchFullAccess"
            ]

  tags = {
    tag-key = "apigwterraform"
  }
}


resource "aws_iam_role" "RoleForLambdaterraform" { #https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role
  name = "RoleForLambdaterraform"
  description= "sapigwterraform desc"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Sid    = ""
        Principal = {
          Service = "lambda.amazonaws.com" # for Lambda Function services
        }
      },
    ]
  })

  managed_policy_arns= [ #granted permissions that is being used by this role
              "arn:aws:iam::aws:policy/AmazonKinesisFullAccess",
              "arn:aws:iam::aws:policy/AmazonS3FullAccess",
              "arn:aws:iam::aws:policy/CloudWatchFullAccess"
            ]

  tags = {
    tag-key = "RoleForLambdaterraform"
  }
}

resource "aws_kinesis_stream" "kinesis-stream" { #https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kinesis_stream
  name             = "kinesis-stream"
  shard_count      = 1
  retention_period = 24 #default 24 (in hours) max 7 days (168 Hours)

  stream_mode_details {
    stream_mode = "PROVISIONED" # or can be on-demand and scale accordingly
  }


}

resource "aws_api_gateway_rest_api" "API-GW" { # API Gateway
  name = "API-GW"
}

resource "aws_api_gateway_resource" "streams" { # Resource creation for API Gateways /XXXX in this case /streams
  parent_id   = aws_api_gateway_rest_api.API-GW.root_resource_id
  path_part   = "streams"
  rest_api_id = aws_api_gateway_rest_api.API-GW.id
}





resource "aws_api_gateway_method" "MyDemoMethod" { # API Gateway method in this case "GET"
  rest_api_id   = aws_api_gateway_rest_api.API-GW.id
  resource_id   = aws_api_gateway_resource.streams.id
  http_method   = "GET"
  authorization = "NONE"

}




 



resource "aws_api_gateway_integration" "myintegration" { # 1st 
  # (resource arguments)
  rest_api_id          = aws_api_gateway_rest_api.API-GW.id
  resource_id          = aws_api_gateway_resource.streams.id
  http_method          = aws_api_gateway_method.MyDemoMethod.http_method
  type                 = "AWS"
  uri                  = "arn:aws:apigateway:eu-central-1:kinesis:action/ListStreams"
  integration_http_method = "POST"
  credentials             = aws_iam_role.RoleForApigwterraform.arn
  cache_key_parameters    = []
  request_parameters      = {
          "integration.request.header.Content-Type" = "'application/json'"
        }
  request_templates       = {
          "application/json" = jsonencode({})
        }
}

resource "aws_api_gateway_method_response" "response_200" { # 1st 
  rest_api_id          = aws_api_gateway_rest_api.API-GW.id
  resource_id          = aws_api_gateway_resource.streams.id
  http_method          = aws_api_gateway_method.MyDemoMethod.http_method
  status_code = "200"
  response_models     = {
          "application/json" = "Empty"
        }

  depends_on = [aws_api_gateway_integration.myintegration]

}

resource "aws_api_gateway_integration_response" "MyDemoIntegrationResponse" { # 1st 
  rest_api_id          = aws_api_gateway_rest_api.API-GW.id
  resource_id          = aws_api_gateway_resource.streams.id
  http_method          = aws_api_gateway_method.MyDemoMethod.http_method
  status_code = aws_api_gateway_method_response.response_200.status_code

  # Transforms the backend JSON response to XML
  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.myintegration]
}


resource "aws_api_gateway_resource" "stream-name" { # 2nd resource 
  parent_id   = aws_api_gateway_resource.streams.id
  path_part   = "{stream-name}"
  rest_api_id = aws_api_gateway_rest_api.API-GW.id
}


resource "aws_api_gateway_method" "secondfunction" { # 2nd function 
  rest_api_id   = aws_api_gateway_rest_api.API-GW.id
  resource_id   = aws_api_gateway_resource.stream-name.id
  http_method   = "GET"
  authorization = "NONE"

}



resource "aws_api_gateway_integration" "secondIntegration" { # Integration Request for 2nd function
  # (resource arguments)
  rest_api_id          = aws_api_gateway_rest_api.API-GW.id
  resource_id   = aws_api_gateway_resource.stream-name.id
  http_method          = "GET"
  type                 = "AWS"
  uri                  = "arn:aws:apigateway:eu-central-1:kinesis:action/DescribeStream"
  integration_http_method = "POST"
  credentials             = aws_iam_role.RoleForApigwterraform.arn
  cache_key_parameters    = []
  request_parameters      = {
          "integration.request.header.Content-Type" = "'application/json'"
        }
  request_templates       = {
          "application/json" = jsonencode({
            "StreamName": "$input.params('stream-name')"
          })
        }
}


resource "aws_api_gateway_integration_response" "IntegrationResponse2ndFunction" { # Integration Response for 2nd function
  rest_api_id          = aws_api_gateway_rest_api.API-GW.id
  resource_id   = aws_api_gateway_resource.stream-name.id
  http_method          = "GET"
  status_code = aws_api_gateway_method_response.response_200_for2nd.status_code

  # Transforms the backend JSON response to XML
  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.secondIntegration]

}

resource "aws_api_gateway_method_response" "response_200_for2nd" { # Method Response for 2nd function
  rest_api_id          = aws_api_gateway_rest_api.API-GW.id
  resource_id   = aws_api_gateway_resource.stream-name.id
  http_method          = "GET"
  status_code = "200"
  response_models     = {
          "application/json" = "Empty"
        }

  depends_on = [aws_api_gateway_integration.secondIntegration]

}

# ========================================================================================

resource "aws_api_gateway_resource" "record" { # 3rd resource 
  parent_id   = aws_api_gateway_resource.stream-name.id
  path_part   = "record"
  rest_api_id = aws_api_gateway_rest_api.API-GW.id
}


resource "aws_api_gateway_method" "thirdmethod" { # 3rd function 
  rest_api_id   = aws_api_gateway_rest_api.API-GW.id
  resource_id   = aws_api_gateway_resource.record.id
  http_method   = "PUT"
  authorization = "NONE"

}



resource "aws_api_gateway_integration" "thirdIntegration" { # Integration Request for 3rd function
  # (resource arguments)
  rest_api_id   = aws_api_gateway_rest_api.API-GW.id
  resource_id   = aws_api_gateway_resource.record.id
  http_method   = "PUT"
  type                 = "AWS"
  uri                  = "arn:aws:apigateway:eu-central-1:kinesis:action/PutRecord"
  integration_http_method = "POST"
  credentials             = aws_iam_role.RoleForApigwterraform.arn
  cache_key_parameters    = []
  request_parameters      = {
          "integration.request.header.Content-Type" = "'application/json'"
        }
  request_templates       = {
          "application/json" = jsonencode({
            "StreamName": "$input.params('stream-name')",
            "Data": "$util.base64Encode($input.json('$.Data'))",
            "PartitionKey": "$input.path('$.PartitionKey')"
          })
        }
}


resource "aws_api_gateway_integration_response" "IntegrationResponsethirdFunction" { # Integration Response for 3rd function
  rest_api_id   = aws_api_gateway_rest_api.API-GW.id
  resource_id   = aws_api_gateway_resource.record.id
  http_method   = "PUT"
  status_code = aws_api_gateway_method_response.response_200_forthird.status_code
  response_parameters = {
          "method.response.header.Access-Control-Allow-Origin" = "'*'" # COPS enable
        }


  # Transforms the backend JSON response to XML
  response_templates = {
    "application/json" = ""
  }

  depends_on = [aws_api_gateway_integration.thirdIntegration]
}

resource "aws_api_gateway_method_response" "response_200_forthird" { # Method Response for 3rd function
  rest_api_id   = aws_api_gateway_rest_api.API-GW.id
  resource_id   = aws_api_gateway_resource.record.id
  http_method   = "PUT"
  status_code = "200"
  response_parameters = {
          "method.response.header.Access-Control-Allow-Origin" = false # COPS enable
        }

  response_models     = {
          "application/json" = "Empty"
        }

  depends_on = [aws_api_gateway_integration.thirdIntegration]


}


#===============================================================================================================================
resource "aws_s3_bucket" "dresdenbucket" {
  bucket = "dresdenbucket"
}

resource "aws_s3_bucket_versioning" "versioning_example" {
  bucket = aws_s3_bucket.dresdenbucket.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_acl" "dresden-acl" {
  bucket = aws_s3_bucket.dresdenbucket.id
  acl    = "private"
}

resource "aws_s3_bucket_public_access_block" "mypublicblock" {
  bucket = aws_s3_bucket.dresdenbucket.id
  block_public_acls = true
  block_public_policy = true
  ignore_public_acls = true
  restrict_public_buckets = true
}


resource "aws_sns_topic" "bucket_notification" {
  name = "bucket_topic"
  policy = <<EOF
{
    "Version":"2012-10-17",
    "Statement":[{
        "Effect": "Allow",
        "Principal": { "Service": "s3.amazonaws.com" },
        "Action": "SNS:Publish",
        "Resource": "arn:aws:sns:::s3-event-notification-topic",
        "Condition":{
            "ArnLike":{"aws:SourceArn":"aws_s3_bucket.dresdenbucket.arn"}
        }
    }]
}
EOF
}

resource "aws_sns_topic_subscription" "send_email_when_something_wrong" {
  endpoint  = "yildirimustafa3@gmail.com"
  protocol  = "email"
  topic_arn = aws_sns_topic.bucket_notification.arn
}

resource "aws_s3_bucket_notification" "mybucketnotification" {
  bucket = aws_s3_bucket.dresdenbucket.id

  lambda_function {
    
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = ""
    filter_suffix       = ".json"
    lambda_function_arn = aws_lambda_function.producer.arn
    id= "notificationid"
  }

  depends_on = [aws_lambda_permission.mypermission]
}



resource "aws_lambda_function" "producer" { # https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function
  filename      = "producer.zip" # a zip file contains "index.js" #needs to be in same path where this tf runs
  function_name = "producer"
  role          = aws_iam_role.RoleForLambdaterraform.arn
  handler       = "index.test"

  # The filebase64sha256() function is available in Terraform 0.11.12 and later
  # For Terraform 0.11.11 and earlier, use the base64sha256() function and the file() function:
  # source_code_hash = "${base64sha256(file("lambda_function_payload.zip"))}"
  source_code_hash = filebase64sha256("producer.zip")

  runtime = "nodejs14.x"

  environment {
    variables = {
      foo = "bar"
    }
  }
}

resource "aws_lambda_permission" "mypermission" {
  statement_id  = "AllowExecutionFromS3Bucket"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.producer.arn
  principal     = "s3.amazonaws.com"
  source_arn    = aws_s3_bucket.dresdenbucket.arn
}





resource "aws_iam_role" "RoleForFirehose" {
  name = "RoleForFirehose"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "firehose.amazonaws.com"
      },
      "Effect": "Allow",
      "Sid": ""
    }
  ]
}
EOF

  managed_policy_arns= [
              "arn:aws:iam::aws:policy/AmazonKinesisFullAccess",
              "arn:aws:iam::aws:policy/AmazonS3FullAccess",
              "arn:aws:iam::aws:policy/CloudWatchFullAccess"
            ]
}





resource "aws_kinesis_firehose_delivery_stream" "myfirehosedeliverystream" {
  name= "mustafa"
  destination= "extended_s3"
  extended_s3_configuration {
    role_arn   = aws_iam_role.RoleForFirehose.arn
    bucket_arn = aws_s3_bucket.dresdenbucket.arn
    buffer_interval    = 60 #second, default 300, max 900 seconds
    buffer_size = 5 # default 5MB can be between 1-128MB
    compression_format= "UNCOMPRESSED"
  }

  kinesis_source_configuration {
                kinesis_stream_arn= aws_kinesis_stream.kinesis-stream.arn
                role_arn= aws_iam_role.RoleForFirehose.arn
              }
}

output "API-GW-ARN" {
  value = aws_api_gateway_rest_api.API-GW.arn
}