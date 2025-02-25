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
  default     = null  # Será criado automaticamente se não fornecido
}

variable "task_role_arn" {
  description = "ARN do task role"
  type        = string
  default     = null  # Será criado automaticamente se não fornecido
}

variable "ecr_repository_url" {
  description = "URL do repositório ECR"
  type        = string
  default     = null  # Será criado automaticamente se não fornecido
}

variable "container_environment" {
  description = "Variáveis de ambiente para o container"
  type        = list(map(string))
  default     = []
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

variable "desired_count" {
  description = "Número desejado de tasks"
  type        = number
  default     = 1
}

variable "min_capacity" {
  description = "Capacidade mínima do auto scaling"
  type        = number
  default     = 1
}

variable "max_capacity" {
  description = "Capacidade máxima do auto scaling"
  type        = number
  default     = 4
}

variable "target_cpu_utilization" {
  description = "Target de utilização de CPU para scaling (percentual)"
  type        = number
  default     = 70
}

variable "target_memory_utilization" {
  description = "Target de utilização de memória para scaling (percentual)"
  type        = number
  default     = 70
}

variable "target_alb_request_count" {
  description = "Target de requisições por target para scaling"
  type        = number
  default     = 1000  # Requisições por minuto por target
}

variable "alarm_actions" {
  description = "Lista de ARNs para notificação de alarmes (ex: SNS)"
  type        = list(string)
  default     = []
}

variable "scale_in_cooldown" {
  description = "Tempo em segundos antes de permitir outro scale in"
  type        = number
  default     = 300
}

variable "scale_out_cooldown" {
  description = "Tempo em segundos antes de permitir outro scale out"
  type        = number
  default     = 180
}

variable "efs_performance_mode" {
  description = "Performance mode do EFS (generalPurpose ou maxIO)"
  type        = string
  default     = "generalPurpose"
}

variable "efs_throughput_mode" {
  description = "Throughput mode do EFS (bursting ou provisioned)"
  type        = string
  default     = "bursting"
}

variable "efs_provisioned_throughput" {
  description = "Throughput provisionado em MiB/s (se modo provisioned)"
  type        = number
  default     = null
}

variable "efs_ia_lifecycle_policy" {
  description = "Política de transição para IA (em dias)"
  type        = string
  default     = "AFTER_30_DAYS"
}

variable "vpc_id" {
  description = "ID da VPC"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets"
  type        = list(string)
}

variable "environment_variables" {
  description = "Variáveis de ambiente para o container"
  type        = map(string)
  default     = {}
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

variable "secrets_region" {
  description = "Região onde os secrets estão armazenados"
  type        = string
  default     = null  # Se null, usa a mesma região do provider principal
}

locals {
  secrets_region = coalesce(var.secrets_region, var.aws_region)
} 