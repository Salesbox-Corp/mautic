#!/bin/bash

# Verificar argumentos
AWS_REGION=${1:-"us-east-2"}  # Região padrão se não especificada

echo "Iniciando setup da infraestrutura base na região ${AWS_REGION}..."

# Obter ID da conta AWS
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="mautic-terraform-lock"

# O state key agora inclui a região
STATE_KEY="base/${AWS_REGION}/terraform.tfstate"

echo "Limpando state anterior se existir..."

# Remover state do S3 se existir
aws s3 rm "s3://${BUCKET_NAME}/${STATE_KEY}" || true

# Remover entrada do DynamoDB
aws dynamodb delete-item \
    --table-name ${DYNAMODB_TABLE} \
    --key '{"LockID": {"S": "'${BUCKET_NAME}'/'${STATE_KEY}'-md5"}}' || true

echo "Iniciando setup da infraestrutura base..."

# Navegar para o diretório correto
cd terraform/base

# Inicializar Terraform com backend configuration
terraform init \
    -backend-config="bucket=${BUCKET_NAME}" \
    -backend-config="key=${STATE_KEY}" \
    -force-copy

# Aplicar configuração com a região especificada
terraform apply -auto-approve \
    -var="aws_region=${AWS_REGION}"

# Obter outputs importantes
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
VPC_ID=$(terraform output -raw vpc_id)
SUBNET_IDS=$(terraform output -raw public_subnet_ids)
RDS_MASTER_USER=$(terraform output -raw rds_username)
RDS_MASTER_PASSWORD=$(terraform output -raw rds_password)

# Salvar endpoint do RDS no SSM (não sensível)
aws ssm put-parameter \
    --name "/mautic/${AWS_REGION}/shared/rds/endpoint" \
    --value "${RDS_ENDPOINT}" \
    --type "String" \
    --overwrite

# Salvar credenciais do RDS master no Secrets Manager
aws secretsmanager create-secret \
    --name "/mautic/${AWS_REGION}/shared/rds/master" \
    --secret-string "{
        \"username\": \"${RDS_MASTER_USER}\",
        \"password\": \"${RDS_MASTER_PASSWORD}\"
    }"

# Salvar informações da VPC no SSM
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

echo "Setup da infraestrutura base concluído na região ${AWS_REGION}" 