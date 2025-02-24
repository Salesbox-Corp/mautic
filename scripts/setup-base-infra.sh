#!/bin/bash

# Verificar argumentos
AWS_REGION=${1:-"us-east-2"}
FORCE_DELETE_STATE=${FORCE_DELETE_STATE:-"false"}

echo "Iniciando setup da infraestrutura base na região ${AWS_REGION}..."
echo "Forçar deleção do estado: ${FORCE_DELETE_STATE}"

# Configurações do backend
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="mautic-terraform-lock"
STATE_KEY="regions/${AWS_REGION}/terraform.tfstate"

# 1. Setup do Backend (sempre em us-east-1)
echo "Configurando backend..."

# Criar/verificar bucket
aws s3api create-bucket \
    --bucket ${BUCKET_NAME} \
    --region us-east-1 2>/dev/null || true

aws s3api put-bucket-versioning \
    --bucket ${BUCKET_NAME} \
    --versioning-configuration Status=Enabled

# Criar/verificar tabela DynamoDB
aws dynamodb create-table \
    --table-name ${DYNAMODB_TABLE} \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST \
    --region us-east-1 2>/dev/null || true

# 2. Se forçar deleção do estado, recriar do zero
if [ "${FORCE_DELETE_STATE}" = "true" ]; then
    echo "Recriando estado do zero..."
    
    # Remover estado do S3
    aws s3 rm "s3://${BUCKET_NAME}/${STATE_KEY}"
    
    # Dropar e recriar a tabela DynamoDB
    aws dynamodb delete-table \
        --table-name ${DYNAMODB_TABLE} \
        --region us-east-1 2>/dev/null || true
    
    echo "Aguardando deleção da tabela..."
    aws dynamodb wait table-not-exists \
        --table-name ${DYNAMODB_TABLE} \
        --region us-east-1
    
    echo "Recriando tabela DynamoDB..."
    aws dynamodb create-table \
        --table-name ${DYNAMODB_TABLE} \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST \
        --region us-east-1
        
    echo "Aguardando criação da tabela..."
    aws dynamodb wait table-exists \
        --table-name ${DYNAMODB_TABLE} \
        --region us-east-1
fi

# 3. Limpar diretório local
echo "Limpando arquivos locais..."
cd terraform/base
rm -rf .terraform*
rm -f terraform.tfstate*

# 4. Inicializar e aplicar Terraform
echo "Iniciando Terraform..."

# Inicializar backend
terraform init \
    -backend-config="bucket=${BUCKET_NAME}" \
    -backend-config="key=${STATE_KEY}" \
    -backend-config="region=us-east-1" \
    -backend-config="dynamodb_table=${DYNAMODB_TABLE}" \
    -force-copy

# Aplicar configuração
terraform apply -auto-approve \
    -var="aws_region=${AWS_REGION}"

# 5. Salvar outputs
echo "Salvando outputs..."

RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
VPC_ID=$(terraform output -raw vpc_id)
SUBNET_IDS=$(terraform output -raw public_subnet_ids)
RDS_MASTER_USER=$(terraform output -raw rds_username)
RDS_MASTER_PASSWORD=$(terraform output -raw rds_password)

# Salvar no SSM e Secrets Manager
aws ssm put-parameter \
    --name "/mautic/${AWS_REGION}/shared/rds/endpoint" \
    --value "${RDS_ENDPOINT}" \
    --type "String" \
    --overwrite

aws secretsmanager create-secret \
    --name "/mautic/${AWS_REGION}/shared/rds/master" \
    --secret-string "{\"username\":\"${RDS_MASTER_USER}\",\"password\":\"${RDS_MASTER_PASSWORD}\"}" \
    --force-overwrite-replica-secret 2>/dev/null || \
aws secretsmanager update-secret \
    --secret-id "/mautic/${AWS_REGION}/shared/rds/master" \
    --secret-string "{\"username\":\"${RDS_MASTER_USER}\",\"password\":\"${RDS_MASTER_PASSWORD}\"}"

aws ssm put-parameter \
    --name "/mautic/${AWS_REGION}/shared/vpc/id" \
    --value "${VPC_ID}" \
    --type "String" \
    --overwrite

aws ssm put-parameter \
    --name "/mautic/${AWS_REGION}/shared/vpc/subnet_ids" \
    --value "${SUBNET_IDS}" \
    --type "StringList" \
    --overwrite

echo "Setup concluído com sucesso!" 