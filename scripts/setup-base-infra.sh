#!/bin/bash

# Verificar argumentos
AWS_REGION=${1:-"us-east-2"}  # Região padrão se não especificada

echo "Iniciando setup da infraestrutura base na região ${AWS_REGION}..."

# Obter ID da conta AWS
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="mautic-terraform-lock"

echo "Limpando states antigos..."

# Forçar remoção de todos os states e locks relacionados
for KEY in "base/terraform.tfstate" "base/${AWS_REGION}/terraform.tfstate"; do
    echo "Limpando state: ${KEY}"
    
    # Remover state do S3
    aws s3 rm "s3://${BUCKET_NAME}/${KEY}" || true
    
    # Remover entradas do DynamoDB
    aws dynamodb delete-item \
        --table-name ${DYNAMODB_TABLE} \
        --key '{"LockID": {"S": "'${BUCKET_NAME}'/'${KEY}'"}}' || true
    
    aws dynamodb delete-item \
        --table-name ${DYNAMODB_TABLE} \
        --key '{"LockID": {"S": "'${BUCKET_NAME}'/'${KEY}'-md5"}}' || true
done

echo "Iniciando setup da infraestrutura base..."

# Navegar para o diretório correto
cd terraform/base

# Remover diretório .terraform se existir
rm -rf .terraform

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