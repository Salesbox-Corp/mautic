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
  default     = "10.0.0.0/16"
}

variable "availability_zones" {
  description = "AZs a serem utilizadas"
  type        = list(string)
  default     = ["us-east-1a", "us-east-1b", "us-east-1c"]
}

variable "private_subnet_cidrs" {
  description = "CIDRs das subnets privadas"
  type        = list(string)
  default     = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas"
  type        = list(string)
  default     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
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