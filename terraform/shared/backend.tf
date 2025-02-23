terraform {
  backend "s3" {
    bucket         = "mautic-terraform-state-${data.aws_caller_identity.current.account_id}"
    key            = "shared/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "mautic-terraform-lock"
    encrypt        = true
  }
}

data "aws_caller_identity" "current" {} 