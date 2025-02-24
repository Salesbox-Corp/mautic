# Buscar VPC existente
data "aws_vpc" "existing" {
  tags = {
    Name        = "mautic-shared-vpc"
    Environment = "shared"
    Project     = "mautic"
    ManagedBy   = "terraform"
  }

  state = "available"
}

# Buscar subnets públicas existentes
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  filter {
    name   = "tag:Type"
    values = ["public"]
  }

  filter {
    name   = "tag:Environment"
    values = ["shared"]
  }
}

# Outputs usando a VPC existente
output "vpc_id" {
  value = data.aws_vpc.existing.id
}

output "public_subnet_ids" {
  value = data.aws_subnets.public.ids
}

variable "aws_region" {
  description = "AWS Region"
  type        = string
} 