resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
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
          },
          {
            name  = "MAUTIC_INSTALL_SOURCE"
            value = "TERRAFORM"
          },
          {
            name  = "MAUTIC_TABLE_PREFIX"
            value = ""
          },
          {
            name  = "MAUTIC_DB_PORT"
            value = "3306"
          },
          {
            name  = "MAUTIC_DB_PREFIX"
            value = ""
          },
          {
            name  = "MAUTIC_SKIP_INSTALL"
            value = "true"
          },
          {
            name  = "MAUTIC_CUSTOM_LOGO_URL"
            value = var.custom_logo_url
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

# Gerar identificador único para os security groups
resource "random_id" "sg_suffix" {
  byte_length = 4
}

# Security Group para o ALB
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb-sg-${random_id.sg_suffix.hex}"
  description = "Security group for Application Load Balancer"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTP traffic from internet"
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow HTTPS traffic from internet"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-alb-sg-${random_id.sg_suffix.hex}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Security Group para tasks ECS
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks-sg-${random_id.sg_suffix.hex}"
  description = "Security group for ECS tasks"
  vpc_id      = var.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-ecs-tasks-sg-${random_id.sg_suffix.hex}"
  })

  lifecycle {
    create_before_destroy = true
  }
}

# Buscar o log group existente em vez de tentar criar um novo
data "aws_cloudwatch_log_group" "ecs" {
  name = "/ecs/${var.project_name}"
}

resource "aws_ecs_service" "main" {
  name            = "${var.project_name}-service"
  cluster         = aws_ecs_cluster.main.id
  task_definition = aws_ecs_task_definition.mautic.arn
  desired_count   = var.desired_count
  launch_type     = "FARGATE"
  
  deployment_maximum_percent         = 200
  deployment_minimum_healthy_percent = 100
  health_check_grace_period_seconds = 60

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = [aws_security_group.ecs_tasks.id]
    assign_public_ip = true
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.main.arn
    container_name   = "mautic"
    container_port   = 80
  }

  deployment_controller {
    type = "ECS"
  }

  enable_ecs_managed_tags = true
  propagate_tags         = "SERVICE"
  
  depends_on = [
    aws_lb_listener.http,
    aws_lb_listener.https,
    aws_security_group.ecs_tasks,
    aws_security_group.alb,
    aws_lb_target_group.main
  ]

  lifecycle {
    create_before_destroy = true
  }
}

# Adicionar target group para o ALB
resource "aws_lb_target_group" "main" {
  name        = "${var.project_name}-tg"
  port        = 80
  protocol    = "HTTP"
  vpc_id      = var.vpc_id
  target_type = "ip"

  health_check {
    enabled             = true
    healthy_threshold   = 2
    unhealthy_threshold = 10
    interval            = 30
    timeout            = 5
    path               = "/index.php"
    port               = "traffic-port"
    protocol           = "HTTP"
    matcher            = "300-399,200-299"
  }

  tags = var.tags
  
  # Garantir que o ALB seja criado antes do target group
  depends_on = [aws_lb.main]
}

# Configuração do Route 53
resource "aws_route53_record" "mautic" {
  provider = aws.us-east-1  # Route 53 está na região us-east-1
  zone_id  = var.hosted_zone_id
  name     = "${var.subdomain}.${var.domain}"
  type     = "A"

  alias {
    name                   = aws_lb.main.dns_name
    zone_id               = aws_lb.main.zone_id
    evaluate_target_health = true
  }
}

# Modificar o listener HTTP para usar o certificado existente
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type = "redirect"
    redirect {
      port        = "443"
      protocol    = "HTTPS"
      status_code = "HTTP_301"
    }
  }
}

# Criar um novo certificado ACM na região atual
resource "aws_acm_certificate" "mautic" {
  domain_name       = "${var.subdomain}.${var.domain}"
  validation_method = "DNS"

  lifecycle {
    create_before_destroy = true
  }

  tags = merge(var.tags, {
    Name = "${var.project_name}-certificate"
  })
}

# Criar registro de validação DNS para o certificado
resource "aws_route53_record" "cert_validation" {
  provider = aws.us-east-1  # Route 53 está na região us-east-1
  for_each = {
    for dvo in aws_acm_certificate.mautic.domain_validation_options : dvo.domain_name => {
      name   = dvo.resource_record_name
      record = dvo.resource_record_value
      type   = dvo.resource_record_type
    }
  }

  zone_id = var.hosted_zone_id
  name    = each.value.name
  type    = each.value.type
  records = [each.value.record]
  ttl     = 60
}

# Esperar pela validação do certificado
resource "aws_acm_certificate_validation" "mautic" {
  certificate_arn         = aws_acm_certificate.mautic.arn
  validation_record_fqdns = [for record in aws_route53_record.cert_validation : record.fqdn]
}

# Modificar o listener HTTPS para usar o novo certificado
resource "aws_lb_listener" "https" {
  load_balancer_arn = aws_lb.main.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  
  # Usar o novo certificado criado na região atual
  certificate_arn   = aws_acm_certificate_validation.mautic.certificate_arn

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.main.arn
  }
  
  # Garantir que o target group seja criado antes do listener
  depends_on = [aws_lb_target_group.main, aws_acm_certificate_validation.mautic]
} 