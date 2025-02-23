#!/bin/bash

CLIENT=$1
ENVIRONMENT=$2

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./init-client.sh <client_name> <environment>"
    exit 1
fi

# Obter ID da conta AWS
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"

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

# Criar repositório ECR
aws ecr create-repository \
    --repository-name "mautic-${CLIENT}-${ENVIRONMENT}" \
    --image-scanning-configuration scanOnPush=true

# Inicializar e aplicar Terraform
cd "${CLIENT_DIR}"

terraform init \
    -backend-config="bucket=${BUCKET_NAME}" \
    -backend-config="key=clients/${CLIENT}/${ENVIRONMENT}/terraform.tfstate" \
    -backend-config="dynamodb_table=mautic-terraform-lock"

terraform apply -auto-approve 