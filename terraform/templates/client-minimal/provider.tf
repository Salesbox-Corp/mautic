terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider principal para a região do cliente
provider "aws" {
  region = var.aws_region
}

# Provider específico para Route 53 (sempre em us-east-1)
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
} 