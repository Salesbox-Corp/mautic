module "naming" {
  source = "../../../modules/naming"
  
  client      = var.client
  environment = var.environment
  project     = var.project
}

module "networking" {
  source = "../../../modules/networking"
  
  project_name         = module.naming.prefix
  vpc_cidr            = var.vpc_cidr
  availability_zones  = var.availability_zones
  public_subnet_cidrs = var.public_subnet_cidrs
  tags                = module.naming.tags
}

module "database" {
  source = "../../../modules/database"
  
  project_name         = module.naming.prefix
  db_name             = module.naming.db_prefix
  db_username         = var.db_username
  instance_class      = var.db_instance_class
  db_subnet_group_name = module.networking.database_subnet_group
  vpc_security_group_ids = [module.networking.database_security_group_id]
  tags                = module.naming.tags
}

module "ecs" {
  source = "../../../modules/ecs"
  
  project_name       = module.naming.prefix
  task_cpu          = var.task_cpu
  task_memory       = var.task_memory
  ecr_repository_url = var.ecr_repository_url
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.public_subnet_ids
  tags              = module.naming.tags
  
  environment_variables = {
    MAUTIC_DB_HOST     = module.database.endpoint
    MAUTIC_DB_NAME     = module.database.name
    MAUTIC_DB_USER     = module.database.username
    MAUTIC_DB_PASSWORD = module.database.password
  }
} 