client      = "${CLIENT}"
environment = "${ENVIRONMENT}"
project     = "mautic"
aws_region  = "${AWS_REGION}"

# Configurações de recursos
task_cpu    = 1024
task_memory = 2048

# Configurações de rede
vpc_id       = "${VPC_ID}"
subnet_ids   = "${SUBNET_IDS}"

# Configurações do banco de dados
db_host     = "${RDS_ENDPOINT}"
db_name     = "${DB_NAME}"
db_username = "${DB_USER}"

# Configurações do ECR
ecr_repository_url = "${ECR_REPO_URL}"

# Remover estas variáveis pois agora usamos VPC compartilhada
# vpc_cidr   = "172.31.128.0/24"
# availability_zones  = ["us-east-1a", "us-east-1b"]
# public_subnet_cidrs = ["172.31.128.0/25", "172.31.128.128/25"] 