module "naming" {
  source = "../../../modules/naming"
  
  client      = var.client
  environment = var.environment
  project     = var.project
}

module "shared_vpc" {
  source = "../../../modules/shared_vpc"
}

module "ecs" {
  source = "../../../modules/ecs"
  
  project_name       = module.naming.prefix
  task_cpu          = var.task_cpu
  task_memory       = var.task_memory
  vpc_id            = module.shared_vpc.vpc_id
  subnet_ids        = module.shared_vpc.public_subnet_ids
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