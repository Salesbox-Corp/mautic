terraform {
  backend "s3" {
    bucket         = "seu-bucket-terraform-state"
    key            = "mautic/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-state-lock"
    encrypt        = true
  }
} 