terraform {
  backend "s3" {
    # O bucket de state SEMPRE deve estar em us-east-1
    # independente da região onde os recursos serão criados
    region         = "us-east-1"  # Região fixa para o bucket de state
    dynamodb_table = "mautic-terraform-lock"
    encrypt        = true
    # bucket e key serão passados via -backend-config
  }
} 