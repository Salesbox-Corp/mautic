terraform {
  backend "s3" {
    region         = "us-east-1"
    dynamodb_table = "mautic-terraform-lock"
    encrypt        = true
  }
}

data "aws_caller_identity" "current" {} 