#!/bin/bash

CLIENT=$1
ENVIRONMENT=$2
VERSION=$3  # Opcional: versão específica para rollback

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./rollback-client.sh <client_name> <environment> [version]"
    exit 1
fi

# Obter ID da conta AWS
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"
STATE_KEY="clients/${CLIENT}/${ENVIRONMENT}/terraform.tfstate"

# Verificar se o state existe
if ! aws s3api head-object --bucket ${BUCKET_NAME} --key ${STATE_KEY} 2>/dev/null; then
    echo "State file não encontrado. Provavelmente primeira execução falhou."
    echo "Limpando recursos parcialmente criados..."
    
    # Limpar recursos específicos do cliente
    echo "Removendo banco de dados do cliente..."
    RDS_CREDENTIALS=$(aws secretsmanager get-secret-value \
        --secret-id "/mautic/shared/rds/master" \
        --query 'SecretString' --output text)
    
    RDS_ENDPOINT=$(aws ssm get-parameter --name "/mautic/shared/rds/endpoint" --query "Parameter.Value" --output text)
    MASTER_USER=$(echo $RDS_CREDENTIALS | jq -r '.username')
    MASTER_PASSWORD=$(echo $RDS_CREDENTIALS | jq -r '.password')
    
    DB_NAME="mautic_${CLIENT}_${ENVIRONMENT}"
    DB_USER="${DB_NAME}_user"
    
    mysql -h $RDS_ENDPOINT -u $MASTER_USER -p${MASTER_PASSWORD} <<EOF
    DROP DATABASE IF EXISTS ${DB_NAME};
    DROP USER IF EXISTS '${DB_USER}'@'%';
    FLUSH PRIVILEGES;
EOF

    # Remover repositório ECR
    echo "Removendo repositório ECR..."
    aws ecr delete-repository \
        --repository-name "mautic-${CLIENT}-${ENVIRONMENT}" \
        --force || true

    # Remover secrets e parâmetros
    echo "Removendo secrets e parâmetros..."
    aws secretsmanager delete-secret \
        --secret-id "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" \
        --force-delete-without-recovery || true

    aws ssm delete-parameters \
        --names \
            "/mautic/${CLIENT}/${ENVIRONMENT}/config/domain" \
            "/mautic/${CLIENT}/${ENVIRONMENT}/config/email_from" \
            "/mautic/${CLIENT}/${ENVIRONMENT}/database/name" \
            "/mautic/${CLIENT}/${ENVIRONMENT}/database/user" || true

    # Verificar e remover security groups
    echo "Removendo security groups..."
    SG_NAME="mautic-${CLIENT}-${ENVIRONMENT}"
    SG_IDS=$(aws ec2 describe-security-groups --filters "Name=group-name,Values=${SG_NAME}*" --query 'SecurityGroups[*].GroupId' --output text)
    for SG_ID in $SG_IDS; do
        aws ec2 delete-security-group --group-id $SG_ID || true
    done

    echo "Limpeza concluída"
    exit 0
fi

# Se o state existe, fazer rollback normal
echo "Versões disponíveis do state:"
aws s3api list-object-versions \
    --bucket ${BUCKET_NAME} \
    --prefix ${STATE_KEY} \
    --query 'Versions[*].[VersionId,LastModified]' \
    --output table

if [ -z "$VERSION" ]; then
    # Se versão não foi especificada, pegar a penúltima versão
    VERSION=$(aws s3api list-object-versions \
        --bucket ${BUCKET_NAME} \
        --prefix ${STATE_KEY} \
        --query 'Versions[1].VersionId' \
        --output text)
fi

echo "Fazendo rollback para versão: $VERSION"

# Criar diretório temporário
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# Baixar versão anterior do state
aws s3api get-object \
    --bucket ${BUCKET_NAME} \
    --key ${STATE_KEY} \
    --version-id ${VERSION} \
    terraform.tfstate

# Copiar código Terraform do cliente
mkdir -p terraform/environments/clients/${CLIENT}/${ENVIRONMENT}
cp -r /workspace/terraform/environments/clients/${CLIENT}/${ENVIRONMENT}/* .

# Inicializar Terraform
terraform init \
    -backend-config="bucket=${BUCKET_NAME}" \
    -backend-config="key=${STATE_KEY}" \
    -backend-config="dynamodb_table=mautic-terraform-lock"

# Fazer rollback da infraestrutura
terraform destroy -auto-approve

# Limpar
cd -
rm -rf $TEMP_DIR

echo "Rollback concluído para ${CLIENT}/${ENVIRONMENT}" 