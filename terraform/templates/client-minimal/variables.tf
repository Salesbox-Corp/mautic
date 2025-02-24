# Remover variáveis relacionadas à VPC pois agora é compartilhada
variable "client" {
  description = "Nome do cliente"
  type        = string
}

variable "environment" {
  description = "Ambiente (demo/staging/prd)"
  type        = string
}

variable "project" {
  description = "Nome do projeto"
  type        = string
}

variable "aws_region" {
  description = "AWS Region"
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

variable "db_host" {
  description = "Host do banco de dados"
  type        = string
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
}

variable "db_username" {
  description = "Usuário do banco de dados"
  type        = string
}

variable "execution_role_arn" {
  description = "ARN do execution role"
  type        = string
  default     = null
}

variable "task_role_arn" {
  description = "ARN do task role"
  type        = string
  default     = null
}

variable "ecr_repository_url" {
  description = "URL do repositório ECR"
  type        = string
  default     = null
}

# ... outras variáveis necessárias ... 