# Buscar VPC compartilhada
data "aws_vpc" "shared" {
  tags = {
    Name = "mautic-shared-vpc"
  }
}

# Buscar subnets públicas
data "aws_subnets" "public" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.shared.id]
  }
  
  tags = {
    Type = "public"
  }
}

output "vpc_id" {
  value = data.aws_vpc.shared.id
}

output "public_subnet_ids" {
  value = data.aws_subnets.public.ids
} 