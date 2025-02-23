module "shared_vpc" {
  source = "../shared_vpc"
  aws_region = var.aws_region
}

resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  # Habilitar Capacity Providers
  capacity_providers = ["FARGATE", "FARGATE_SPOT"]
  default_capacity_provider_strategy {
    capacity_provider = "FARGATE_SPOT"  # Usar Spot por padrão
    weight = 1
    base   = 0
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

  volume {
    name = "mautic-data"
    efs_volume_configuration {
      file_system_id          = aws_efs_file_system.mautic.id
      root_directory          = "/"
      transit_encryption      = "ENABLED"
      transit_encryption_port = 2049
      authorization_config {
        access_point_id = aws_efs_access_point.mautic.id
        iam_auth        = "ENABLED"
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
          value = data.aws_secretsmanager_secret_version.db_credentials.secret_string
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

# Configurar Auto Scaling
resource "aws_appautoscaling_target" "ecs" {
  max_capacity       = var.max_capacity
  min_capacity       = var.min_capacity
  resource_id        = "service/${aws_ecs_cluster.main.name}/${aws_ecs_service.main.name}"
  scalable_dimension = "ecs:service:DesiredCount"
  service_namespace  = "ecs"
}

# Scaling por CPU
resource "aws_appautoscaling_policy" "cpu" {
  name               = "${var.project_name}-cpu-scaling"
  policy_type        = "TargetTrackingScaling"
  resource_id        = aws_appautoscaling_target.ecs.resource_id
  scalable_dimension = aws_appautoscaling_target.ecs.scalable_dimension
  service_namespace  = aws_appautoscaling_target.ecs.service_namespace

  target_tracking_scaling_policy_configuration {
    target_value = var.target_cpu_utilization
    scale_in_cooldown  = 300
    scale_out_cooldown = 300

    predefined_metric_specification {
      predefined_metric_type = "ECSServiceAverageCPUUtilization"
    }
  }
} 