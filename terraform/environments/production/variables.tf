variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "project_name" {
  description = "Nome do projeto"
  type        = string
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