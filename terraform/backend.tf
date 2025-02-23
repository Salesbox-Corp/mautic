terraform {
  backend "s3" {
    bucket         = "mautic-clients-terraform-state"
    key            = "${var.project}/${var.client}/${var.environment}/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "mautic-clients-terraform-lock"
    encrypt        = true
  }
} 