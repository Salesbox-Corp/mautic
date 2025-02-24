client      = "{{CLIENT}}"
environment = "{{ENVIRONMENT}}"
project     = "mautic"
aws_region  = "us-east-1"

# Remover estas variáveis pois agora usamos VPC compartilhada
# vpc_cidr   = "172.31.128.0/24"
# availability_zones  = ["us-east-1a", "us-east-1b"]
# public_subnet_cidrs = ["172.31.128.0/25", "172.31.128.128/25"]

task_cpu    = 1024
task_memory = 2048

# Estas variáveis serão preenchidas pelo script setup-client.sh
db_host     = ""
db_name     = ""
db_username = "" 