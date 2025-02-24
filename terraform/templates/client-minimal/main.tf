module "naming" {
  source = "../../../../modules/naming"
  
  client      = var.client
  environment = var.environment
  project     = var.project
}

module "shared_vpc" {
  source = "../../../../modules/shared_vpc"
  aws_region = var.aws_region
}

# Criar roles do ECS
resource "aws_iam_role" "ecs_execution" {
  name = "${module.naming.prefix}-ecs-execution"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_role" "ecs_task" {
  name = "${module.naming.prefix}-ecs-task"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        }
      }
    ]
  })
}

# Criar repositório ECR
resource "aws_ecr_repository" "mautic" {
  name = "mautic-${var.client}-${var.environment}"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

module "ecs" {
  source = "../../../../modules/ecs"
  
  project_name       = module.naming.prefix
  aws_region        = var.aws_region
  task_cpu          = var.task_cpu
  task_memory       = var.task_memory
  vpc_id            = module.shared_vpc.vpc_id
  subnet_ids        = module.shared_vpc.public_subnet_ids
  tags              = module.naming.tags
  client            = var.client
  environment       = var.environment
  
  execution_role_arn = aws_iam_role.ecs_execution.arn
  task_role_arn      = aws_iam_role.ecs_task.arn
  ecr_repository_url = aws_ecr_repository.mautic.repository_url

  container_environment = []  # Será configurado via SSM/Secrets Manager
}

# Buscar senha do banco do SSM
data "aws_ssm_parameter" "db_password" {
  name = "/mautic/${var.client}/${var.environment}/db/password"
} 