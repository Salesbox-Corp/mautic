module "naming" {
  source = "./modules/naming"
  
  client      = var.client
  environment = var.environment
  project     = var.project
}

# Buscar VPC compartilhada existente
data "aws_vpcs" "shared" {
  filter {
    name   = "tag:Name"
    values = ["mautic-shared-vpc"]
  }

  filter {
    name   = "tag:Environment"
    values = ["shared"]
  }

  filter {
    name   = "tag:Project"
    values = ["mautic"]
  }

  filter {
    name   = "tag:ManagedBy"
    values = ["terraform"]
  }
}

locals {
  vpc_id = tolist(data.aws_vpcs.shared.ids)[0]
}

# Buscar subnets públicas ao invés das privadas
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }

  filter {
    name   = "tag:Type"
    values = ["public"]  # Alterado de private para public
  }

  filter {
    name   = "tag:Environment"
    values = ["shared"]
  }
}

# Obter ID da conta AWS
data "aws_caller_identity" "current" {}

# Tentar usar roles existentes
data "aws_iam_role" "ecs_execution" {
  name = "${module.naming.prefix}-ecs-execution"
}

data "aws_iam_role" "ecs_task" {
  name = "${module.naming.prefix}-ecs-task"
}

# Criar repositório ECR apenas se não existir
resource "aws_ecr_repository" "mautic" {
  count = var.ecr_exists == "true" ? 0 : 1
  
  name = "mautic-${var.client}-${var.environment}"
  
  image_scanning_configuration {
    scan_on_push = true
  }
}

# Usar data source para repositório existente
data "aws_ecr_repository" "existing_mautic" {
  count = var.ecr_exists == "true" ? 1 : 0
  name  = "mautic-${var.client}-${var.environment}"
}

module "ecs" {
  source = "./modules/ecs"
  
  providers = {
    aws = aws
    aws.us-east-1 = aws.us-east-1
  }

  project_name       = module.naming.prefix
  aws_region        = var.aws_region
  task_cpu          = var.task_cpu
  task_memory       = var.task_memory
  vpc_id            = local.vpc_id
  subnet_ids        = data.aws_subnets.public.ids
  tags              = module.naming.tags
  client            = var.client
  environment       = var.environment
  custom_logo_url   = var.custom_logo_url
  
  execution_role_arn = data.aws_iam_role.ecs_execution.arn
  task_role_arn      = data.aws_iam_role.ecs_task.arn
  ecr_repository_url = var.ecr_exists == "true" ? data.aws_ecr_repository.existing_mautic[0].repository_url : aws_ecr_repository.mautic[0].repository_url

  # Adicionar variáveis do banco de dados
  db_host     = var.db_host
  db_name     = var.db_name
  db_username = var.db_username

  # Adicionar variáveis de domínio
  domain         = var.domain
  subdomain      = var.subdomain
  hosted_zone_id = var.hosted_zone_id

  container_environment = []
}

# Adicionar políticas necessárias ao execution role
resource "aws_iam_role_policy" "ecs_execution_ecr" {
  name = "${module.naming.prefix}-ecs-execution-ecr"
  role = data.aws_iam_role.ecs_execution.id

  lifecycle {
    create_before_destroy = true
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:GetRepositoryPolicy",
          "ecr:DescribeRepositories",
          "ecr:ListImages",
          "ecr:DescribeImages",
          "ecr:TagResource",
          "ecr:UntagResource"
        ]
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_execution_logs" {
  name = "${module.naming.prefix}-ecs-execution-logs"
  role = data.aws_iam_role.ecs_execution.id

  lifecycle {
    create_before_destroy = true
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:CreateLogGroup",
          "logs:DescribeLogStreams",
          "logs:DescribeLogGroups"
        ]
        Resource = [
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${module.naming.prefix}*",
          "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:log-group:/ecs/${module.naming.prefix}*:log-stream:*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy" "ecs_execution_ssm" {
  name = "${module.naming.prefix}-ecs-execution-ssm"
  role = data.aws_iam_role.ecs_execution.id

  lifecycle {
    create_before_destroy = true
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/mautic/${var.client}/${var.environment}/*",
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:/mautic/${var.client}/${var.environment}/*",
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*"
        ]
      }
    ]
  })
}

# Política para o task role
resource "aws_iam_role_policy" "ecs_task_permissions" {
  name = "${module.naming.prefix}-ecs-task-permissions"
  role = data.aws_iam_role.ecs_task.id

  lifecycle {
    create_before_destroy = true
  }

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ssm:GetParameters",
          "ssm:GetParameter",
          "ssm:GetParametersByPath",
          "secretsmanager:GetSecretValue",
          "kms:Decrypt",
          "s3:GetObject",
          "s3:PutObject",
          "s3:ListBucket",
          "ses:SendEmail",
          "ses:SendRawEmail"
        ]
        Resource = [
          "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/mautic/${var.client}/${var.environment}/*",
          "arn:aws:secretsmanager:${var.aws_region}:${data.aws_caller_identity.current.account_id}:secret:/mautic/${var.client}/${var.environment}/*",
          "arn:aws:kms:${var.aws_region}:${data.aws_caller_identity.current.account_id}:key/*",
          "arn:aws:s3:::${module.naming.prefix}-*/*",
          "arn:aws:ses:${var.aws_region}:${data.aws_caller_identity.current.account_id}:identity/*"
        ]
      }
    ]
  })
} 