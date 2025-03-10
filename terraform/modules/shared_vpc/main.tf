# Tentar buscar VPC existente primeiro
data "aws_vpc" "existing" {
  count = var.create_vpc ? 0 : 1
  
  tags = {
    Name        = "mautic-shared-vpc"
    Environment = "shared"
    Project     = "mautic"
    ManagedBy   = "terraform"
  }

  state = "available"
}

# Criar VPC se não existir ou se forçado
module "vpc" {
  count = var.create_vpc ? 1 : 0
  
  source = "terraform-aws-modules/vpc/aws"
  version = "~> 5.0"

  name = "mautic-shared-vpc"
  cidr = var.vpc_cidr

  azs             = local.availability_zones
  public_subnets  = var.public_subnet_cidrs
  
  # Desabilitar NAT Gateway e usar apenas Internet Gateway
  enable_nat_gateway     = false
  enable_vpn_gateway     = false
  enable_dns_hostnames   = true
  enable_dns_support     = true
  
  # Tags para as subnets
  public_subnet_tags = {
    Type = "public"
    "kubernetes.io/role/elb" = "1"  # Para futura compatibilidade com EKS
  }

  tags = merge(var.tags, {
    Name        = "mautic-shared-vpc"
    Environment = "shared"
    Project     = "mautic"
    ManagedBy   = "terraform"
  })
}

locals {
  # Usar VPC existente ou nova
  vpc_id = var.create_vpc ? module.vpc[0].vpc_id : data.aws_vpc.existing[0].id
  
  # Calcular AZs baseado na região se não especificado
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : [
    "${var.aws_region}a",
    "${var.aws_region}b"
  ]
}

# Buscar subnets existentes
data "aws_subnets" "public" {
  count = var.create_vpc ? 0 : 1
  
  filter {
    name   = "vpc-id"
    values = [local.vpc_id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["public"]
  }
}

# Outputs
output "vpc_id" {
  value = local.vpc_id
}

output "public_subnet_ids" {
  value = var.create_vpc ? module.vpc[0].public_subnets : data.aws_subnets.public[0].ids
} 