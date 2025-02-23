# Provider configuration
provider "aws" {
  region = var.aws_region
}

# VPC Compartilhada
module "shared_vpc" {
  source = "../modules/shared_vpc"
  aws_region = var.aws_region
}

# RDS Compartilhado
module "shared_rds" {
  source = "../modules/shared_database"
  
  identifier = "mautic-shared-db"
  instance_class = "db.t3.medium"
  allocated_storage = 20
  max_allocated_storage = 100
  
  engine = "mariadb"
  engine_version = "11.4.4"
  
  db_name = "mautic_master"
  username = "mautic_admin"
  
  vpc_id = module.shared_vpc.vpc_id
  public_subnet_ids = module.shared_vpc.public_subnet_ids
  aws_region = var.aws_region
  
  backup_retention_period = 7
  multi_az = true
  
  tags = {
    Project = "mautic"
    Environment = "shared"
    ManagedBy = "terraform"
  }
}

# Salvar endpoint do RDS no SSM
resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "/mautic/shared/rds/endpoint"
  type  = "String"
  value = module.shared_rds.endpoint
}

# Salvar credenciais no Secrets Manager
resource "aws_secretsmanager_secret" "rds_credentials" {
  name = "/mautic/shared/rds/master"
}

resource "aws_secretsmanager_secret_version" "rds_credentials" {
  secret_id = aws_secretsmanager_secret.rds_credentials.id
  secret_string = jsonencode({
    username = module.shared_rds.username
    password = module.shared_rds.password
  })
}

# Outputs
output "vpc_id" {
  value = module.shared_vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.shared_vpc.public_subnet_ids
}

output "rds_endpoint" {
  value = module.shared_rds.endpoint
}

output "rds_username" {
  value = module.shared_rds.username
}

output "rds_password" {
  value = module.shared_rds.password
  sensitive = true
} 