variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "172.31.128.0/24"
}

variable "availability_zones" {
  description = "AZs a serem utilizadas"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas"
  type        = list(string)
  default     = [
    "172.31.128.0/26",
    "172.31.128.64/26",
    "172.31.128.128/26"
  ]
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas"
  type        = list(string)
  default     = [
    "172.31.128.0/25",
    "172.31.128.128/25",
  ]
}

variable "db_instance_class" {
  description = "Classe da instância RDS"
  type        = string
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
}

variable "db_username" {
  description = "Username do banco de dados"
  type        = string
}

variable "task_cpu" {
  description = "CPU para task do ECS"
  type        = number
  default     = 1024
}

variable "task_memory" {
  description = "Memória para task do ECS"
  type        = number
  default     = 2048
}

variable "ecr_repository_url" {
  description = "URL do repositório ECR"
  type        = string
}

variable "certificate_arn" {
  description = "ARN do certificado SSL"
  type        = string
}

variable "common_tags" {
  description = "Tags comuns para todos os recursos"
  type        = map(string)
  default     = {
    Environment = "production"
    Project     = "mautic"
    Terraform   = "true"
  }
} 