# Tentar buscar VPC existente
data "aws_vpc" "existing" {
  count = 0  # Inicialmente não buscar, vamos criar sempre no primeiro deploy

  tags = {
    Name = "mautic-shared-vpc"
  }
}

# Criar VPC se não existir
module "vpc" {
  source = "terraform-aws-modules/vpc/aws"

  name = "mautic-shared-vpc"
  cidr = "172.31.0.0/16"

  azs             = ["us-east-1a", "us-east-1b"]
  public_subnets  = ["172.31.1.0/24", "172.31.2.0/24"]
  
  enable_nat_gateway = false
  enable_vpn_gateway = false

  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name        = "mautic-shared-vpc"
    Environment = "shared"
    Project     = "mautic"
    ManagedBy   = "terraform"
  }

  public_subnet_tags = {
    Type = "public"
  }
}

# Outputs usando a VPC criada
output "vpc_id" {
  value = module.vpc.vpc_id
}

output "public_subnet_ids" {
  value = module.vpc.public_subnets
} 