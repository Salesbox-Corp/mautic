terraform {
  backend "s3" {
    # Estas configurações serão fornecidas via -backend-config
    # bucket = "mautic-terraform-state-XXXXXXXXXXXX"
    # key    = "base/terraform.tfstate"
    # region = "us-east-1"
    dynamodb_table = "mautic-terraform-lock"
    encrypt        = true
  }
} 