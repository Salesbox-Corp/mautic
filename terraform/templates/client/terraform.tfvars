client      = "{{CLIENT}}"
environment = "{{ENVIRONMENT}}"
project     = "mautic"

aws_region = "us-east-1"
vpc_cidr   = "172.31.128.0/24"

availability_zones  = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs = [
  "172.31.128.0/25",
  "172.31.128.128/25"
]

db_instance_class = "db.t3.small"
db_username       = "mautic_admin"

task_cpu    = 1024
task_memory = 2048

# Será preenchido automaticamente pelo script
ecr_repository_url = "{{ECR_REPO_URL}}" 