variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "task_cpu" {
  description = "CPU para task do ECS"
  type        = number
}

variable "task_memory" {
  description = "Memória para task do ECS"
  type        = number
}

variable "execution_role_arn" {
  description = "ARN do execution role"
  type        = string
}

variable "task_role_arn" {
  description = "ARN do task role"
  type        = string
}

variable "ecr_repository_url" {
  description = "URL do repositório ECR"
  type        = string
}

variable "container_environment" {
  description = "Variáveis de ambiente para o container"
  type        = list(map(string))
}

variable "aws_region" {
  description = "Região AWS"
  type        = string
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
}

variable "client" {
  description = "Nome do cliente"
  type        = string
}

variable "environment" {
  description = "Ambiente (demo/staging/prod)"
  type        = string
} 