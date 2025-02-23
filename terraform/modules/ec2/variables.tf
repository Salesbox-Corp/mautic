variable "aws_region" {
  description = "AWS Region para criar os recursos"
  type        = string
}

variable "availability_zones" {
  description = "Lista de AZs para usar"
  type        = list(string)
  default     = []  # Se vazio, será calculado baseado na região
} 