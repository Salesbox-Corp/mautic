# Remover estas variáveis
# variable "vpc_id" {
#   description = "ID da VPC compartilhada"
#   type        = string
# }

# variable "subnet_ids" {
#   description = "IDs das subnets compartilhadas"
#   type        = list(string)
# }

# Manter apenas as variáveis necessárias
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

variable "ecr_exists" {
  description = "Indica se o repositório ECR já existe"
  type        = string
  default     = "false"
}

# ... outras variáveis necessárias ... 