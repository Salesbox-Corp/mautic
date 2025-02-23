variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
}

variable "aws_region" {
  description = "AWS Region para criar os recursos"
  type        = string
}

variable "availability_zones" {
  description = "Lista de AZs para usar"
  type        = list(string)
  default     = []
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas"
  type        = list(string)
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas"
  type        = list(string)
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
}

locals {
  # Calcular AZs baseado na região se não especificado
  availability_zones = length(var.availability_zones) > 0 ? var.availability_zones : [
    "${var.aws_region}a",
    "${var.aws_region}b"
  ]
} 