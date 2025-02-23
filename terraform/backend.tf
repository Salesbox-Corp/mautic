terraform {
  backend "s3" {
    region         = "us-east-2"
    dynamodb_table = "mautic-terraform-lock"
    encrypt        = true
    # bucket e key serão passados via -backend-config na inicialização
  }
} 