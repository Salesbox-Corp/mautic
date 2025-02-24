# Provider configuration
provider "aws" {
  region = var.aws_region
}

# VPC Compartilhada
module "shared_vpc" {
  source = "../modules/shared_vpc"
  
  aws_region = var.aws_region
  create_vpc = true  # Forçar criação de nova VPC
  
  tags = {
    Environment = "shared"
    Project     = "mautic"
    ManagedBy   = "terraform"
  }
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

# Salvar credenciais no Secrets Manager
resource "aws_secretsmanager_secret" "rds_master" {
  name = "/mautic/shared/rds/master"
}

resource "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = aws_secretsmanager_secret.rds_master.id
  secret_string = jsonencode({
    username = module.shared_rds.username
    password = module.shared_rds.password
  })
}

# Salvar informações não sensíveis no SSM
resource "aws_ssm_parameter" "rds_endpoint" {
  name  = "/mautic/shared/rds/endpoint"
  type  = "String"
  value = module.shared_rds.endpoint
}

resource "aws_ssm_parameter" "vpc_id" {
  name  = "/mautic/shared/vpc/id"
  type  = "String"
  value = module.shared_vpc.vpc_id
}

resource "aws_ssm_parameter" "subnet_ids" {
  name  = "/mautic/shared/vpc/subnet_ids"
  type  = "StringList"
  value = join(",", module.shared_vpc.public_subnet_ids)
}

# Outputs para referência
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