#!/bin/bash

CLIENT=$1
ENVIRONMENT=$2

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./setup-client.sh <client_name> <environment>"
    exit 1
fi

echo "Iniciando setup para ${CLIENT} em ambiente ${ENVIRONMENT}..."

# Login no ECR
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.us-east-2.amazonaws.com

# Criar secrets e configurações
./scripts/manage-secrets.sh create_client_secrets $CLIENT $ENVIRONMENT

# Criar banco de dados do cliente
./scripts/manage-database.sh create_client_database $CLIENT $ENVIRONMENT

# Criar e aplicar Terraform com as configurações
CLIENT_DIR="terraform/environments/clients/${CLIENT}/${ENVIRONMENT}"
mkdir -p "${CLIENT_DIR}"

# Gerar terraform.tfvars (sem configurações de VPC)
cat > "${CLIENT_DIR}/terraform.tfvars" <<EOF
client      = "${CLIENT}"
environment = "${ENVIRONMENT}"
project     = "mautic"

aws_region = "us-east-1"

task_cpu    = 1024
task_memory = 2048

db_name     = "$(aws ssm get-parameter --name "/mautic/${CLIENT}/${ENVIRONMENT}/database/name" --query "Parameter.Value" --output text)"
db_host     = "$(aws ssm get-parameter --name "/mautic/shared/rds/endpoint" --query "Parameter.Value" --output text)"
db_username = "$(aws ssm get-parameter --name "/mautic/${CLIENT}/${ENVIRONMENT}/database/user" --query "Parameter.Value" --output text)"

domain_name = "$(aws ssm get-parameter --name "/mautic/${CLIENT}/${ENVIRONMENT}/config/domain" --query "Parameter.Value" --output text)"
EOF

# Copiar main.tf template
cp terraform/templates/client-minimal/* "${CLIENT_DIR}/"

# Inicializar e aplicar Terraform
cd "${CLIENT_DIR}"
terraform init
terraform apply -auto-approve

echo "Setup concluído para ${CLIENT}/${ENVIRONMENT}" 