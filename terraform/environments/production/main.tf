provider "aws" {
  region = var.aws_region
}

module "networking" {
  source = "../../modules/networking"
  
  project_name         = var.project_name
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  private_subnet_cidrs = var.private_subnet_cidrs
  public_subnet_cidrs  = var.public_subnet_cidrs
  tags                = var.common_tags
}

module "database" {
  source = "../../modules/database"
  
  project_name    = var.project_name
  db_name        = var.db_name
  db_username    = var.db_username
  instance_class = var.db_instance_class
  tags           = var.common_tags
  
  depends_on = [module.networking]
}

module "ecs" {
  source = "../../modules/ecs"
  
  project_name       = var.project_name
  task_cpu          = var.task_cpu
  task_memory       = var.task_memory
  ecr_repository_url = var.ecr_repository_url
  tags              = var.common_tags
  
  depends_on = [module.networking, module.database]
} 