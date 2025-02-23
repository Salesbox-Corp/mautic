#!/bin/bash

CLIENT=$1
ENVIRONMENT=$2

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./init-client.sh <client_name> <environment>"
    exit 1
fi

# Definir variáveis
CLIENT_DIR="terraform/environments/clients/${CLIENT}/${ENVIRONMENT}"
TEMPLATE_DIR="terraform/templates"

# Criar estrutura de diretórios
echo "Criando estrutura para ${CLIENT}/${ENVIRONMENT}..."
mkdir -p "${CLIENT_DIR}"

# Copiar templates
cp -r "${TEMPLATE_DIR}/client/"* "${CLIENT_DIR}/"

# Substituir placeholders nos arquivos
sed -i "s/{{CLIENT}}/${CLIENT}/g" "${CLIENT_DIR}/terraform.tfvars"
sed -i "s/{{ENVIRONMENT}}/${ENVIRONMENT}/g" "${CLIENT_DIR}/terraform.tfvars"

# Criar bucket S3 para estado do Terraform
aws s3api create-bucket \
    --bucket "mautic-${CLIENT}-${ENVIRONMENT}-state" \
    --region us-east-1

# Habilitar versionamento do bucket
aws s3api put-bucket-versioning \
    --bucket "mautic-${CLIENT}-${ENVIRONMENT}-state" \
    --versioning-configuration Status=Enabled

# Criar tabela DynamoDB para lock
aws dynamodb create-table \
    --table-name "mautic-${CLIENT}-${ENVIRONMENT}-lock" \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

# Criar repositório ECR
aws ecr create-repository \
    --repository-name "mautic-${CLIENT}-${ENVIRONMENT}" \
    --image-scanning-configuration scanOnPush=true

# Inicializar e aplicar Terraform
cd "${CLIENT_DIR}"

terraform init \
    -backend-config="bucket=mautic-${CLIENT}-${ENVIRONMENT}-state" \
    -backend-config="key=terraform.tfstate" \
    -backend-config="dynamodb_table=mautic-${CLIENT}-${ENVIRONMENT}-lock"

terraform apply -auto-approve 