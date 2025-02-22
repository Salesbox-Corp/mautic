variable "project_name" {
  description = "Nome do projeto"
  type        = string
}

variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
}

variable "allocated_storage" {
  description = "Tamanho do storage em GB"
  type        = number
  default     = 20
}

variable "max_allocated_storage" {
  description = "Tamanho máximo do storage em GB"
  type        = number
  default     = 100
}

variable "db_name" {
  description = "Nome do banco de dados"
  type        = string
}

variable "db_username" {
  description = "Username do banco de dados"
  type        = string
}

variable "multi_az" {
  description = "Habilitar Multi-AZ"
  type        = bool
  default     = true
}

variable "db_subnet_group_name" {
  description = "Nome do subnet group"
  type        = string
}

variable "vpc_security_group_ids" {
  description = "IDs dos security groups"
  type        = list(string)
}

variable "maintenance_window" {
  description = "Janela de manutenção"
  type        = string
  default     = "Mon:00:00-Mon:03:00"
}

variable "backup_window" {
  description = "Janela de backup"
  type        = string
  default     = "03:00-06:00"
}

variable "backup_retention_period" {
  description = "Período de retenção do backup em dias"
  type        = number
  default     = 7
}

variable "skip_final_snapshot" {
  description = "Pular snapshot final"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
} 