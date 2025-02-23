# VPC para o RDS compartilhado
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "mautic-shared-vpc"
  cidr = "172.31.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["172.31.1.0/24", "172.31.2.0/24"]
  
  enable_nat_gateway = false
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Environment = "shared"
    Project     = "mautic"
    ManagedBy   = "terraform"
  }
}

module "shared_rds" {
  source = "../modules/shared_database"
  
  identifier = "mautic-shared-db"
  instance_class = "db.t3.medium"
  allocated_storage = 20
  max_allocated_storage = 100
  
  engine = "mariadb"
  engine_version = "10.3"
  
  db_name = "mautic_master"
  username = "mautic_admin"
  
  vpc_id = module.vpc.vpc_id
  public_subnet_ids = module.vpc.public_subnets
  
  backup_retention_period = 7
  multi_az = true
  
  tags = {
    Project = "mautic"
    Environment = "shared"
    ManagedBy = "terraform"
  }
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