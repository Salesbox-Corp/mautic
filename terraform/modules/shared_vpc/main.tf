# Buscar VPC existente
data "aws_vpc" "existing" {
  tags = {
    Name = "mautic-shared-vpc"
  }
}

# Buscar subnets públicas existentes
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.existing.id]
  }
  
  tags = {
    Type = "public"
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