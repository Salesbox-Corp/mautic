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
  
  backup_retention_period = 7
  multi_az = true
  
  tags = {
    Project = "mautic"
    Environment = "shared"
    ManagedBy = "terraform"
  }
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