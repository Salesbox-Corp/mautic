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

module "ecs" {
  source = "../../../modules/ecs"
  
  project_name       = module.naming.prefix
  task_cpu          = var.task_cpu
  task_memory       = var.task_memory
  vpc_id            = module.networking.vpc_id
  subnet_ids        = module.networking.public_subnet_ids
  tags              = module.naming.tags
  
  environment_variables = {
    MAUTIC_DB_HOST     = var.db_host
    MAUTIC_DB_NAME     = var.db_name
    MAUTIC_DB_USER     = var.db_username
    MAUTIC_DB_PASSWORD = data.aws_ssm_parameter.db_password.value
  }
}

# Buscar senha do banco do SSM
data "aws_ssm_parameter" "db_password" {
  name = "/mautic/${var.client}/${var.environment}/db/password"
} 