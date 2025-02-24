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

# Login no ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin $(aws sts get-caller-identity --query Account --output text).dkr.ecr.${AWS_REGION}.amazonaws.com

# Criar parâmetros SSM primeiro
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

# Gerar senhas
DB_PASSWORD=$(openssl rand -base64 32)
MAUTIC_ADMIN_PASSWORD=$(openssl rand -base64 16)

# Criar secret com credenciais
aws secretsmanager create-secret \
    --name "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" \
    --secret-string "{
        \"db_password\": \"${DB_PASSWORD}\",
        \"mautic_admin_user\": \"admin\",
        \"mautic_admin_password\": \"${MAUTIC_ADMIN_PASSWORD}\",
        \"mautic_admin_email\": \"admin@${CLIENT}.com\"
    }" || true

# Obter endpoint do RDS do SSM
RDS_ENDPOINT=$(aws ssm get-parameter \
  --name "/mautic/shared/rds/endpoint" \
  --query "Parameter.Value" \
  --output text)

# Obter credenciais do RDS master do Secrets Manager
RDS_MASTER_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "/mautic/shared/rds/master" \
  --query 'SecretString' --output text)

MASTER_USER=$(echo $RDS_MASTER_SECRET | jq -r '.username')
MASTER_PASSWORD=$(echo $RDS_MASTER_SECRET | jq -r '.password')

# Criar banco e usuário para o cliente
DB_NAME="mautic_${CLIENT}_${ENVIRONMENT}"
DB_USER="${DB_NAME}_user"

echo "Criando banco de dados ${DB_NAME}..."
mysql -h "${RDS_ENDPOINT}" \
  -u "${MASTER_USER}" \
  -p"${MASTER_PASSWORD}" \
  --protocol=TCP <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF

# Criar diretório do cliente
mkdir -p "${CLIENT_DIR}"

# Copiar templates usando envsubst
export CLIENT ENVIRONMENT AWS_REGION RDS_ENDPOINT DB_NAME DB_USER
envsubst < terraform/templates/client-minimal/terraform.tfvars > "${CLIENT_DIR}/terraform.tfvars"

# Copiar outros arquivos do template
cp terraform/templates/client-minimal/main.tf "${CLIENT_DIR}/"
cp terraform/templates/client-minimal/variables.tf "${CLIENT_DIR}/"
cp terraform/templates/client-minimal/backend.tf "${CLIENT_DIR}/"

echo "Setup concluído para ${CLIENT}/${ENVIRONMENT}" 