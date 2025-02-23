variable "client" {
  description = "Nome do cliente"
  type        = string
}

variable "environment" {
  description = "Ambiente (prod, staging, dev)"
  type        = string
}

variable "project" {
  description = "Nome do projeto"
  type        = string
  default     = "mautic"
} 