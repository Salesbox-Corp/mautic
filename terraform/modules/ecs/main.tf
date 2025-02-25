resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }
}

resource "aws_ecs_cluster_capacity_providers" "main" {
  cluster_name = aws_ecs_cluster.main.name

  capacity_providers = ["FARGATE", "FARGATE_SPOT"]

  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight = 1
    base   = 0
  }
}

# Buscar credenciais do banco master
data "aws_secretsmanager_secret" "rds_master" {
  name = "/mautic/${var.aws_region}/shared/rds/master"
}

data "aws_secretsmanager_secret_version" "rds_master" {
  secret_id = data.aws_secretsmanager_secret.rds_master.id
}

# Buscar credenciais do cliente
data "aws_secretsmanager_secret" "db_credentials" {
  name = "/mautic/${var.client}/${var.environment}/credentials"
}

data "aws_secretsmanager_secret_version" "db_credentials" {
  secret_id = data.aws_secretsmanager_secret.db_credentials.id
}

locals {
  master_credentials = jsondecode(data.aws_secretsmanager_secret_version.rds_master.secret_string)
  client_credentials = jsondecode(data.aws_secretsmanager_secret_version.db_credentials.secret_string)
}

resource "aws_ecs_task_definition" "mautic" {
  family                   = "${var.project_name}-task"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = var.task_cpu
  memory                   = var.task_memory
  execution_role_arn       = var.execution_role_arn
  task_role_arn           = var.task_role_arn

  volume {
    name = "mautic-data"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.mautic.id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049
      authorization_config {
        access_point_id = aws_efs_access_point.mautic.id
      }
    }
  }

  container_definitions = jsonencode([
    {
      name  = "mautic"
      image = "${var.ecr_repository_url}:latest"
      
      mountPoints = [
        {
          sourceVolume  = "mautic-data"
          containerPath = "/var/www/html/media"
          readOnly      = false
        }
      ]

      environment = concat(
        [
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
            value = local.client_credentials["db_password"]
          },
          {
            name  = "MAUTIC_ADMIN_USERNAME"
            value = local.client_credentials["mautic_admin_user"]
          },
          {
            name  = "MAUTIC_ADMIN_PASSWORD"
            value = local.client_credentials["mautic_admin_password"]
          },
          {
            name  = "MAUTIC_ADMIN_EMAIL"
            value = local.client_credentials["mautic_admin_email"]
          }
        ],
        var.container_environment
      )

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
  subnets           = var.subnet_ids

  tags = var.tags
}

resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mautic.arn
  desired_count   = var.desired_count
  launch_type     = null  # Necessário remover quando usando capacity providers
  
  # Estratégia de capacity provider
  capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"
    weight = 1
    base   = 0
  }

  # Configuração de deployment
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds = 60

  # Configuração de rede
  network_configuration {
    subnets         = var.subnet_ids
    security_groups = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "mautic"
    container_port   = 80
  }

  # Estratégia de deployment
  deployment_controller {
    type = "ECS"
  }

  # Configuração de auto scaling
  enable_ecs_managed_tags = true
  propagate_tags         = "SERVICE"

  # Configuração de placement
  ordered_placement_strategy {
    type  = "spread"
    field = "attribute:ecs.availability-zone"
  }
}

resource "aws_security_group" "ecs_tasks" {
  vpc_id = var.vpc_id
  # ... resto da configuração ...
}

resource "aws_security_group" "alb" {
  vpc_id = var.vpc_id
  # ... resto da configuração ...
}

# Adicionar target group para o ALB
resource "aws_lb_target_group" "main" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
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