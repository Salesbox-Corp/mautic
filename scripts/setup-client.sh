#!/bin/bash

CLIENT=$1
ENVIRONMENT=$2
AWS_REGION=${3:-"us-east-2"}

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./setup-client.sh <client_name> <environment> [aws_region]"
    exit 1
fi

CLIENT_DIR="terraform/environments/clients/${CLIENT}/${ENVIRONMENT}"

echo "Iniciando setup para ${CLIENT}/${ENVIRONMENT} na região ${AWS_REGION}..."

# Obter informações da infra compartilhada da região específica
echo "Obtendo informações da infraestrutura compartilhada na região ${AWS_REGION}..."

# VPC e Subnets
VPC_ID=$(aws ssm get-parameter \
  --name "/mautic/${AWS_REGION}/shared/vpc/id" \
  --query "Parameter.Value" \
  --output text)

SUBNET_IDS=$(aws ssm get-parameter \
  --name "/mautic/${AWS_REGION}/shared/vpc/subnet_ids" \
  --query "Parameter.Value" \
  --output text)

# RDS Endpoint
RDS_ENDPOINT=$(aws ssm get-parameter \
  --name "/mautic/${AWS_REGION}/shared/rds/endpoint" \
  --query "Parameter.Value" \
  --output text)

# Credenciais RDS Master
RDS_MASTER_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "/mautic/${AWS_REGION}/shared/rds/master" \
  --query 'SecretString' \
  --output text)

MASTER_USER=$(echo $RDS_MASTER_SECRET | jq -r '.username')
MASTER_PASSWORD=$(echo $RDS_MASTER_SECRET | jq -r '.password')

# Gerar senhas para o cliente
DB_PASSWORD=$(openssl rand -base64 32)
MAUTIC_ADMIN_PASSWORD=$(openssl rand -base64 16)

# Criar secret com credenciais do cliente
echo "Criando credenciais do cliente..."
aws secretsmanager create-secret \
    --name "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" \
    --secret-string "{
        \"db_password\": \"${DB_PASSWORD}\",
        \"mautic_admin_user\": \"admin\",
        \"mautic_admin_password\": \"${MAUTIC_ADMIN_PASSWORD}\",
        \"mautic_admin_email\": \"admin@${CLIENT}.com\"
    }" || true

# Criar parâmetros de configuração do cliente
echo "Criando parâmetros de configuração..."
aws ssm put-parameter \
    --name "/mautic/${CLIENT}/${ENVIRONMENT}/config/domain" \
    --value "${CLIENT}-${ENVIRONMENT}.mautic.exemplo.com" \
    --type "String" \
    --overwrite

aws ssm put-parameter \
    --name "/mautic/${CLIENT}/${ENVIRONMENT}/config/email_from" \
    --value "mautic@${CLIENT}.com" \
    --type "String" \
    --overwrite

# Criar banco de dados do cliente
echo "Criando banco de dados..."
DB_NAME="mautic_${CLIENT}_${ENVIRONMENT}"
DB_USER="${DB_NAME}_user"

mysql -h "${RDS_ENDPOINT}" \
  -u "${MASTER_USER}" \
  -p"${MASTER_PASSWORD}" \
  --protocol=TCP <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# Criar repositório ECR
echo "Criando repositório ECR..."
ECR_REPO="mautic-${CLIENT}-${ENVIRONMENT}"
aws ecr create-repository \
    --repository-name "${ECR_REPO}" \
    --image-scanning-configuration scanOnPush=true || true

ECR_REPO_URL=$(aws ecr describe-repositories \
    --repository-names "${ECR_REPO}" \
    --query 'repositories[0].repositoryUri' \
    --output text)

# Criar diretório do cliente e preparar terraform
echo "Preparando configuração Terraform..."
mkdir -p "${CLIENT_DIR}"

# Exportar variáveis para o template
export CLIENT ENVIRONMENT AWS_REGION RDS_ENDPOINT DB_NAME DB_USER ECR_REPO_URL VPC_ID SUBNET_IDS
envsubst < terraform/templates/client-minimal/terraform.tfvars > "${CLIENT_DIR}/terraform.tfvars"

# Copiar outros arquivos do template
cp terraform/templates/client-minimal/main.tf "${CLIENT_DIR}/"
cp terraform/templates/client-minimal/variables.tf "${CLIENT_DIR}/"
cp terraform/templates/client-minimal/backend.tf "${CLIENT_DIR}/"

# Fazer backup do estado atual
aws s3 cp s3://mautic-terraform-state-***/base/terraform.tfstate \
    s3://mautic-terraform-state-***/base/terraform.tfstate.backup

# Remover o estado atual
aws s3 rm s3://mautic-terraform-state-***/base/terraform.tfstate

echo "Setup concluído para ${CLIENT}/${ENVIRONMENT}" 