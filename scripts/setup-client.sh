#!/bin/bash

CLIENT=$1
ENVIRONMENT=$2
AWS_REGION=${3:-"us-east-2"}

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./setup-client.sh <client_name> <environment> [aws_region]"
    exit 1
fi

CLIENT_DIR="terraform/environments/clients/${CLIENT}/${ENVIRONMENT}"
STATE_KEY="regions/${AWS_REGION}/clients/${CLIENT}/${ENVIRONMENT}/terraform.tfstate"

echo "Iniciando setup para ${CLIENT}/${ENVIRONMENT} na região ${AWS_REGION}..."

# Obter informações da infra compartilhada da região específica
echo "Obtendo informações da infraestrutura compartilhada na região ${AWS_REGION}..."

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

# Criar secret com credenciais do cliente (ignorar se já existe)
echo "Verificando/criando credenciais do cliente..."
if ! aws secretsmanager describe-secret --secret-id "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" >/dev/null 2>&1; then
    aws secretsmanager create-secret \
        --name "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" \
        --secret-string "{
            \"db_password\": \"${DB_PASSWORD}\",
            \"mautic_admin_user\": \"admin\",
            \"mautic_admin_password\": \"${MAUTIC_ADMIN_PASSWORD}\",
            \"mautic_admin_email\": \"admin@${CLIENT}.com\"
        }"
else
    echo "Secret já existe, mantendo configuração atual"
fi

# Criar/atualizar parâmetros de configuração
echo "Atualizando parâmetros de configuração..."
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

# Validar endpoint do RDS antes de prosseguir
if [ -z "$RDS_ENDPOINT" ]; then
  echo "Erro: Endpoint do RDS não encontrado no SSM Parameter Store"
  exit 1
fi

# Garantir que o endpoint está no formato correto
# Remover protocolo se existir
RDS_ENDPOINT=$(echo $RDS_ENDPOINT | sed 's|^mysql://||')
# Remover porta se existir
RDS_ENDPOINT=$(echo $RDS_ENDPOINT | sed 's/:[0-9]*$//')

echo "Usando endpoint RDS: ${RDS_ENDPOINT}"

# Antes de criar o banco, verificar se consegue conectar ao RDS
echo "Verificando conexão com RDS..."
if ! mysql -h "${RDS_ENDPOINT}" \
          -u "${MASTER_USER}" \
          -p"${MASTER_PASSWORD}" \
          --protocol=TCP \
          -P 3306 \
          -e "SELECT 1;" > /dev/null 2>&1; then
  echo "Erro: Não foi possível conectar ao RDS em ${RDS_ENDPOINT}"
  echo "Detalhes da conexão (sem senha):"
  echo "Host: ${RDS_ENDPOINT}"
  echo "User: ${MASTER_USER}"
  echo "Protocol: TCP"
  echo "Port: 3306"
  exit 1
fi

# Verificar se o banco já existe antes de criar
echo "Verificando banco de dados..."
DB_EXISTS=$(mysql -h "${RDS_ENDPOINT}" \
    -u "${MASTER_USER}" \
    -p"${MASTER_PASSWORD}" \
    --protocol=TCP \
    -e "SHOW DATABASES LIKE '${DB_NAME}';" | grep ${DB_NAME} || true)

if [ -z "$DB_EXISTS" ]; then
    echo "Criando banco de dados..."
    mysql -h "${RDS_ENDPOINT}" \
        -u "${MASTER_USER}" \
        -p"${MASTER_PASSWORD}" \
        --protocol=TCP <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
else
    echo "Banco de dados já existe, mantendo configuração atual"
fi

# Verificar/criar repositório ECR
echo "Verificando repositório ECR..."
ECR_REPO="mautic-${CLIENT}-${ENVIRONMENT}"
if ! aws ecr describe-repositories --repository-names "${ECR_REPO}" >/dev/null 2>&1; then
    echo "Criando repositório ECR..."
    aws ecr create-repository \
        --repository-name "${ECR_REPO}" \
        --image-scanning-configuration scanOnPush=true
else
    echo "Repositório ECR já existe"
fi

# Obter URL do repositório ECR
ECR_REPO_URL=$(aws ecr describe-repositories \
    --repository-names "${ECR_REPO}" \
    --query 'repositories[0].repositoryUri' \
    --output text)

# Preparar diretório Terraform
echo "Preparando configuração Terraform..."
mkdir -p "${CLIENT_DIR}"

# Exportar variáveis para o template
export CLIENT ENVIRONMENT AWS_REGION RDS_ENDPOINT DB_NAME DB_USER ECR_REPO_URL
envsubst < terraform/templates/client-minimal/terraform.tfvars > "${CLIENT_DIR}/terraform.tfvars"

# Copiar arquivos do template
cp terraform/templates/client-minimal/main.tf "${CLIENT_DIR}/"
sed -i '/^provider "aws" {/,/^}/d' "${CLIENT_DIR}/main.tf"
cp terraform/templates/client-minimal/variables.tf "${CLIENT_DIR}/"

# Após copiar os arquivos do template, remover qualquer referência ao módulo shared_vpc
sed -i '/module "shared_vpc"/,/^}/d' "${CLIENT_DIR}/main.tf"

# Criar provider.tf e backend.tf
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"

# Criar provider.tf
cat > "${CLIENT_DIR}/provider.tf" <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider principal para a região do cliente
provider "aws" {
  region = var.aws_region
}

# Provider para recursos que precisam estar em us-east-1 (como ACM)
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
EOF

# Criar backend.tf
cat > "${CLIENT_DIR}/backend.tf" <<EOF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "${STATE_KEY}"
    region         = "us-east-1"
    dynamodb_table = "mautic-terraform-lock"
    encrypt        = true
  }
}
EOF

# Adicionar esta função no início do script, após as validações iniciais
remove_terraform_lock() {
    local lock_id="$1"
    local table_name="mautic-terraform-lock"
    local state_path="$2"

    echo "Tentando remover lock pendente..."
    aws dynamodb delete-item \
        --table-name "$table_name" \
        --key "{\"LockID\": {\"S\": \"$state_path\"}}" \
        --region "us-east-1"
    
    echo "Lock removido com sucesso"
}

# Atualizar a parte do Terraform para incluir tratamento de lock
cd "${CLIENT_DIR}"
terraform init

echo "Planejando alterações..."
if ! terraform plan -out=tfplan 2>terraform.err; then
    if grep -q "Error acquiring the state lock" terraform.err; then
        # Extrair informações do lock
        LOCK_PATH=$(grep "Path:" terraform.err | awk '{print $2}')
        
        echo "Lock detectado no estado. Tentando remover..."
        remove_terraform_lock "$LOCK_ID" "$LOCK_PATH"
        
        # Tentar novamente com lock removido
        echo "Tentando plan novamente..."
        if ! terraform plan -out=tfplan; then
            echo "Erro no planejamento do Terraform mesmo após remover lock"
            exit 1
        fi
    else
        cat terraform.err
        echo "Erro no planejamento do Terraform"
        exit 1
    fi
fi

echo "Aplicando alterações..."
if ! terraform apply tfplan; then
    echo "Erro na aplicação do Terraform"
    exit 1
fi

# Verificar se o cluster foi criado
CLUSTER_NAME="mautic-${CLIENT}-${ENVIRONMENT}-cluster"
if ! aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].status' --output text | grep -q ACTIVE; then
  echo "Erro: Cluster ECS não foi criado corretamente"
  exit 1
fi

echo "Setup concluído para ${CLIENT}/${ENVIRONMENT}" 