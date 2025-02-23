locals {
  # Padrão: projeto-cliente-ambiente
  name_prefix = "${var.project}-${var.client}-${var.environment}"
  
  # Padrão para RDS: projeto_cliente_ambiente
  db_prefix   = "${var.project}_${var.client}_${var.environment}"
  
  # Tags padrão
  default_tags = {
    Project     = var.project
    Client      = var.client
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

output "prefix" {
  value = local.name_prefix
}

output "db_prefix" {
  value = local.db_prefix
}

output "tags" {
  value = local.default_tags
} 