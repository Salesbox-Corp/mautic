# Apenas variáveis e recursos do ECS
variable "vpc_id" {
  description = "ID da VPC compartilhada"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets privadas compartilhadas"
  type        = list(string)
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
}

# Recursos do ECS
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

# Security Group para o ECS
resource "aws_security_group" "ecs" {
  name        = "${var.project_name}-ecs-sg"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Task Definition e Service
resource "aws_ecs_task_definition" "main" {
  family                   = var.project_name
  requires_compatibilities = ["FARGATE"]
  network_mode            = "awsvpc"
  cpu                     = var.task_cpu
  memory                  = var.task_memory
  execution_role_arn      = var.execution_role_arn
  task_role_arn           = var.task_role_arn

  container_definitions = jsonencode([
    {
      name  = "mautic"
      image = "${var.ecr_repository_url}:latest"
      # ... outras configurações do container ...
    }
  ])

  tags = var.tags
}

resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.main.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs.id]
    assign_public_ip = false
  }

  tags = var.tags
}

# Ajustar o caminho do secret
data "aws_secretsmanager_secret" "rds_master" {
  name = "/mautic/${var.aws_region}/shared/rds/master"
} 