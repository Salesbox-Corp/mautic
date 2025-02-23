#!/bin/bash

CLIENT=$1
ENVIRONMENT=$2
AWS_REGION=${3:-"us-east-2"}  # Região como terceiro parâmetro, default us-east-2

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./setup-client.sh <client_name> <environment> [aws_region]"
    exit 1
fi

echo "Iniciando setup para ${CLIENT}/${ENVIRONMENT} na região ${AWS_REGION}..."

# Login no ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com

# Criar secrets e configurações
./scripts/manage-secrets.sh create_client_secrets $CLIENT $ENVIRONMENT

# Obter endpoint do RDS do SSM
RDS_ENDPOINT=$(aws ssm get-parameter \
  --name "/mautic/shared/rds/endpoint" \
  --query "Parameter.Value" \
  --output text)

# Obter credenciais do RDS do Secrets Manager
RDS_CREDENTIALS=$(aws secretsmanager get-secret-value \
  --secret-id "/mautic/shared/rds/master" \
  --query 'SecretString' --output text)

# Criar banco e usuário para o cliente
DB_NAME="mautic_${CLIENT}_${ENVIRONMENT}"
DB_USER="${DB_NAME}_user"
DB_PASSWORD=$(openssl rand -base64 32)

# Criar banco de dados do cliente
mysql -h $RDS_ENDPOINT \
  -u $(echo $RDS_CREDENTIALS | jq -r '.username') \
  -p$(echo $RDS_CREDENTIALS | jq -r '.password') <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# Salvar credenciais do cliente no Secrets Manager
aws secretsmanager create-secret \
  --name "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" \
  --secret-string "{
    \"db_host\": \"${RDS_ENDPOINT}\",
    \"db_name\": \"${DB_NAME}\",
    \"db_user\": \"${DB_USER}\",
    \"db_password\": \"${DB_PASSWORD}\"
  }"

# Gerar terraform.tfvars com as configurações
cat > "${CLIENT_DIR}/terraform.tfvars" <<EOF
client      = "${CLIENT}"
environment = "${ENVIRONMENT}"
project     = "mautic"
aws_region  = "${AWS_REGION}"

task_cpu    = 1024
task_memory = 2048

db_host     = "${RDS_ENDPOINT}"
db_name     = "${DB_NAME}"
db_username = "${DB_USER}"

domain_name = "$(aws ssm get-parameter --name "/mautic/${CLIENT}/${ENVIRONMENT}/config/domain" --query "Parameter.Value" --output text)"
EOF

# Copiar main.tf template
cp terraform/templates/client-minimal/* "${CLIENT_DIR}/"

# Inicializar e aplicar Terraform
cd "${CLIENT_DIR}"
terraform init
terraform apply -auto-approve

echo "Setup concluído para ${CLIENT}/${ENVIRONMENT}" 