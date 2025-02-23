variable "vpc_id" {
  description = "ID da VPC onde o RDS será criado"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs das subnets públicas para o RDS"
  type        = list(string)
}

variable "aws_region" {
  description = "AWS Region para criar os recursos"
  type        = string
}

variable "identifier" {
  description = "Identificador do RDS"
  type        = string
}

variable "instance_class" {
  description = "Classe da instância RDS"
  type        = string
}

variable "allocated_storage" {
  description = "Tamanho do storage em GB"
  type        = number
}

variable "max_allocated_storage" {
  description = "Tamanho máximo do storage em GB"
  type        = number
}

variable "engine" {
  description = "Engine do RDS"
  type        = string
  default     = "mariadb"
}

variable "engine_version" {
  description = "Versão do engine"
  type        = string
  default     = "11.4.4"
}

variable "family" {
  description = "Família do parameter group"
  type        = string
  default     = "mariadb11.4"
}

variable "db_name" {
  description = "Nome do banco de dados inicial"
  type        = string
}

variable "username" {
  description = "Username do usuário master"
  type        = string
}

variable "backup_retention_period" {
  description = "Período de retenção do backup em dias"
  type        = number
  default     = 7
}

variable "multi_az" {
  description = "Habilitar Multi-AZ"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
} 