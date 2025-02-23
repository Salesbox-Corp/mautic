terraform {
  backend "s3" {
    region         = "us-east-1"  # Mantém região do bucket fixa em us-east-1
    dynamodb_table = "mautic-terraform-lock"
    encrypt        = true
    # bucket e key serão passados via -backend-config na inicialização
  }
} 