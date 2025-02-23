# Remover variáveis relacionadas à VPC pois agora é compartilhada
variable "client" {
  description = "Nome do cliente"
  type        = string
}

variable "environment" {
  description = "Ambiente (demo/staging/prod)"
  type        = string
}

# ... outras variáveis necessárias ... 