#Terraform block consists of below:
# required_providers
# bucket
# terraform version
# terraform behaviour

terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
            version = "~> 5.0"
        }
    }

    backend "s3" {
        bucket = "mohan-remote-state"
        dynamodb_table = "mohan-locking"
        key = "expense-vpc"
        region = "us-east-1"
    }
}

provider "aws" {
    region = "us-east-1"
}