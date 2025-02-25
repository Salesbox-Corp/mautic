# Remover ou comentar esta parte
# module "shared_vpc" {
#   source = "../shared_vpc"
#   ...
# }

# Usar apenas as variáveis
variable "vpc_id" {
  description = "ID da VPC compartilhada"
  type        = string
}

variable "subnet_ids" {
  description = "IDs das subnets compartilhadas"
  type        = list(string)
}

# Usar as variáveis diretamente nos recursos
resource "aws_ecs_cluster" "main" {
  name = "${var.project_name}-cluster"
  
  setting {
    name  = "containerInsights"
    value = "enabled"
  }

  tags = var.tags
}

resource "aws_ecs_task_definition" "main" {
  # ... configuração da task ...
  network_configuration {
    subnets = var.subnet_ids
    # ...
  }
} 