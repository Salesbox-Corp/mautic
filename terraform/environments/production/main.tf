provider "aws" {
  region = var.aws_region
}

module "shared_vpc" {
  source = "../../modules/shared_vpc"
}

module "database" {
  source = "../../modules/database"
  
  project_name    = var.project_name
  db_name        = var.db_name
  db_username    = var.db_username
  instance_class = var.db_instance_class
  tags           = var.common_tags
  
  vpc_id     = module.shared_vpc.vpc_id
  subnet_ids = module.shared_vpc.public_subnet_ids
}

module "ecs" {
  source = "../../modules/ecs"
  
  project_name       = var.project_name
  task_cpu          = var.task_cpu
  task_memory       = var.task_memory
  ecr_repository_url = var.ecr_repository_url
  vpc_id            = module.shared_vpc.vpc_id
  subnet_ids        = module.shared_vpc.public_subnet_ids
  tags              = var.common_tags
  
  depends_on = [module.database]
} 