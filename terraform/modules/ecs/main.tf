resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

# Buscar credenciais do Secrets Manager
data "aws_secretsmanager_secret" "mautic_credentials" {
  name = "/mautic/${var.client}/${var.environment}/credentials"
}

data "aws_secretsmanager_secret_version" "current" {
  secret_id = data.aws_secretsmanager_secret.mautic_credentials.id
}

locals {
  credentials = jsondecode(data.aws_secretsmanager_secret_version.current.secret_string)
}

resource "aws_ecs_task_definition" "mautic" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn           = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "mautic"
      image = "${var.ecr_repository_url}:latest"
      
      environment = [
        {
          name  = "MAUTIC_DB_HOST"
          value = var.db_host
        },
        {
          name  = "MAUTIC_DB_NAME"
          value = var.db_name
        },
        {
          name  = "MAUTIC_DB_USER"
          value = var.db_username
        },
        {
          name  = "MAUTIC_DB_PASSWORD"
          value = local.credentials.db_password
        },
        {
          name  = "MAUTIC_ADMIN_USERNAME"
          value = local.credentials.mautic_admin_user
        },
        {
          name  = "MAUTIC_ADMIN_PASSWORD"
          value = local.credentials.mautic_admin_password
        },
        {
          name  = "MAUTIC_ADMIN_EMAIL"
          value = local.credentials.mautic_admin_email
        }
      ]

      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
          protocol      = "tcp"
        }
      ]

      logConfiguration = {
        logDriver = "awslogs"
        options = {
          awslogs-group         = "/ecs/${var.project_name}"
          awslogs-region        = var.aws_region
          awslogs-stream-prefix = "ecs"
        }
      }
    }
  ])
} 