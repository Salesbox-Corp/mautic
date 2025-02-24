#!/bin/bash

# Obter ID da conta AWS
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="mautic-terraform-lock"

echo "Verificando/corrigindo estado do backend..."

# Verificar se há inconsistência no state
STATE_KEY="base/terraform.tfstate"
if aws s3api head-object --bucket ${BUCKET_NAME} --key ${STATE_KEY} 2>/dev/null; then
    echo "State encontrado, verificando consistência..."
    
    # Calcular checksum do state atual
    TEMP_STATE=$(mktemp)
    aws s3 cp s3://${BUCKET_NAME}/${STATE_KEY} ${TEMP_STATE}
    CALCULATED_CHECKSUM=$(md5sum ${TEMP_STATE} | cut -d' ' -f1)
    
    # Obter checksum armazenado
    STORED_CHECKSUM=$(aws dynamodb get-item \
        --table-name ${DYNAMODB_TABLE} \
        --key '{"LockID": {"S": "mautic-terraform-state-'${AWS_ACCOUNT_ID}'/base/terraform.tfstate-md5"}}' \
        --query 'Item.Digest.S' \
        --output text)
    
    if [ "$CALCULATED_CHECKSUM" != "$STORED_CHECKSUM" ]; then
        echo "Inconsistência detectada, corrigindo..."
        
        # Atualizar checksum no DynamoDB
        aws dynamodb update-item \
            --table-name ${DYNAMODB_TABLE} \
            --key '{"LockID": {"S": "mautic-terraform-state-'${AWS_ACCOUNT_ID}'/base/terraform.tfstate-md5"}}' \
            --update-expression "SET Digest = :digest" \
            --expression-attribute-values '{":digest": {"S": "'${CALCULATED_CHECKSUM}'"}}'
    fi
    
    rm ${TEMP_STATE}
fi

echo "Iniciando setup da infraestrutura base..."

# Navegar para o diretório correto
cd terraform/base

# Inicializar Terraform com backend configuration
terraform init \
    -backend-config="bucket=${BUCKET_NAME}" \
    -backend-config="key=base/terraform.tfstate" \
    -reconfigure

# Aplicar configuração
terraform apply -auto-approve

# Obter outputs importantes
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
VPC_ID=$(terraform output -raw vpc_id)
SUBNET_IDS=$(terraform output -raw public_subnet_ids)

# Após criar a infra base, salvar os endpoints e credenciais

# Salvar endpoint do RDS no SSM (não sensível)
aws ssm put-parameter \
    --name "/mautic/shared/rds/endpoint" \
    --value "${RDS_ENDPOINT}" \
    --type "String" \
    --overwrite

# Salvar credenciais do RDS master no Secrets Manager
aws secretsmanager create-secret \
    --name "/mautic/shared/rds/master" \
    --secret-string "{
        \"username\": \"${RDS_MASTER_USER}\",
        \"password\": \"${RDS_MASTER_PASSWORD}\"
    }"

# Salvar informações da VPC no SSM
aws ssm put-parameter \
    --name "/mautic/shared/vpc/id" \
    --value "${VPC_ID}" \
    --type "String" \
    --overwrite

aws ssm put-parameter \
    --name "/mautic/shared/vpc/subnet_ids" \
    --value "${SUBNET_IDS}" \
    --type "StringList" \
    --overwrite 