terraform {
  backend "s3" {
    bucket         = "mautic-terraform-state"
    key            = "shared/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "mautic-terraform-lock"
    encrypt        = true
  }
} 