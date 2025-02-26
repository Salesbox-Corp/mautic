variable "aws_region" {
  description = "AWS Region para criar os recursos"
  type        = string
}

variable "create_vpc" {
  description = "Se true, cria uma nova VPC. Se false, tenta usar uma existente"
  type        = bool
  default     = true
}

variable "vpc_cidr" {
  description = "CIDR da VPC"
  type        = string
  default     = "172.31.0.0/16"
}

variable "availability_zones" {
  description = "Lista de AZs para usar"
  type        = list(string)
  default     = []
}

variable "public_subnet_cidrs" {
  description = "CIDRs das subnets públicas"
  type        = list(string)
  default     = ["172.31.0.0/24", "172.31.1.0/24"]
}

variable "tags" {
  description = "Tags para os recursos"
  type        = map(string)
  default     = {}
} 