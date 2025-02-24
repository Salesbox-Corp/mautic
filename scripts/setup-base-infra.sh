#!/bin/bash

# Verificar argumentos
AWS_REGION=${1:-"us-east-2"}  # Região padrão se não especificada

echo "Iniciando setup da infraestrutura base na região ${AWS_REGION}..."

# Obter ID da conta AWS
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="mautic-terraform-lock"

echo "Realizando limpeza completa do state..."

# 1. Limpar TODOS os objetos do bucket
echo "Limpando bucket S3..."
aws s3 rm "s3://${BUCKET_NAME}" --recursive

# 2. Limpar TODAS as entradas da tabela DynamoDB
echo "Limpando tabela DynamoDB..."
aws dynamodb scan \
    --table-name ${DYNAMODB_TABLE} \
    --attributes-to-get "LockID" \
    --query "Items[].LockID.S" \
    --output text | \
while read -r lockid; do
    aws dynamodb delete-item \
        --table-name ${DYNAMODB_TABLE} \
        --key "{\"LockID\": {\"S\": \"$lockid\"}}"
done

# 3. Remover diretório .terraform e arquivos de state locais
echo "Limpando arquivos locais..."
cd terraform/base
rm -rf .terraform*
rm -f terraform.tfstate*

echo "Iniciando setup da infraestrutura base..."

# Inicializar Terraform com backend configuration
terraform init \
    -backend-config="bucket=${BUCKET_NAME}" \
    -backend-config="key=base/${AWS_REGION}/terraform.tfstate" \
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