# Verificar se a VPC já existe
data "aws_vpc" "existing" {
  tags = {
    Name = "mautic-shared-vpc"
  }
  
  # Não falhar se não encontrar
  state = "available"
}

locals {
  # Usar VPC existente ou criar nova
  vpc_id = try(data.aws_vpc.existing.id, module.vpc[0].vpc_id)
  
  # Criar VPC apenas se não existir
  create_vpc = data.aws_vpc.existing.id == null
}

# Módulo VPC só será criado se não existir
module "vpc" {
  count = local.create_vpc ? 1 : 0
  
  source = "terraform-aws-modules/vpc/aws"

  name = "mautic-shared-vpc"
  cidr = var.vpc_cidr

  azs             = var.availability_zones
  public_subnets  = var.public_subnet_cidrs
  
  enable_nat_gateway = false
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = merge(var.tags, {
    Name = "mautic-shared-vpc"
  })
}

# Buscar subnets existentes se VPC existir
data "aws_subnets" "public" {
  count = local.create_vpc ? 0 : 1
  
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  tags = {
    Type = "public"
  }
}

locals {
  # Usar subnets existentes ou novas
  subnet_ids = local.create_vpc ? module.vpc[0].public_subnets : data.aws_subnets.public[0].ids
}

# Security Group para ECS tasks (agora em subnet pública)
resource "aws_security_group" "ecs_tasks" {
  name        = "${var.project_name}-ecs-tasks"
  description = "Security group for ECS tasks"
  vpc_id      = local.vpc_id

  ingress {
    from_port       = 80
    to_port         = 80
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  ingress {
    from_port       = 443
    to_port         = 443
    protocol        = "tcp"
    security_groups = [aws_security_group.alb.id]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = var.tags
}

# Security Group para ALB
resource "aws_security_group" "alb" {
  name        = "${var.project_name}-alb"
  description = "Security group for ALB"
  vpc_id      = local.vpc_id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
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

# Outputs
output "vpc_id" {
  value = local.vpc_id
}

output "public_subnet_ids" {
  value = local.subnet_ids
}

output "ecs_security_group_id" {
  value = aws_security_group.ecs_tasks.id
}

output "alb_security_group_id" {
  value = aws_security_group.alb.id
} 