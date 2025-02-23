module "shared_vpc" {
  source = "../shared_vpc"
}

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

resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.alb.id]
  subnets           = module.shared_vpc.public_subnet_ids

  tags = var.tags
}

resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mautic.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets         = module.shared_vpc.public_subnet_ids
    security_groups = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true  # Importante para subnet pública
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "mautic"
    container_port   = 80
  }
}

resource "aws_security_group" "ecs_tasks" {
  vpc_id = module.shared_vpc.vpc_id
  # ... resto da configuração ...
}

resource "aws_security_group" "alb" {
  vpc_id = module.shared_vpc.vpc_id
  # ... resto da configuração ...
}

# Adicionar target group para o ALB
resource "aws_lb_target_group" "main" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = module.shared_vpc.vpc_id
  target_type = "ip"

  health_check {
    healthy_threshold   = "3"
    interval           = "30"
    protocol           = "HTTP"
    matcher           = "200"
    timeout           = "3"
    path              = "/index.php"
    unhealthy_threshold = "2"
  }

  tags = var.tags
}

# Adicionar listener para o ALB
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
} 