#!/bin/bash

# Verificar argumentos
AWS_REGION=${1:-"us-east-2"}  # Região padrão se não especificada
FORCE_DELETE_STATE=${FORCE_DELETE_STATE:-"false"}  # Controle via variável de ambiente

echo "Iniciando setup da infraestrutura base na região ${AWS_REGION}..."
echo "Forçar deleção do estado: ${FORCE_DELETE_STATE}"

# Obter ID da conta AWS
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"
DYNAMODB_TABLE="mautic-terraform-lock"
STATE_KEY="regions/${AWS_REGION}/terraform.tfstate"
LOCK_ID="regions/${AWS_REGION}/terraform.tfstate"

echo "Recriando infraestrutura do backend..."

# 1. Criar bucket se não existir (sempre em us-east-1)
echo "Verificando/criando bucket S3..."
if ! aws s3api head-bucket --bucket ${BUCKET_NAME} 2>/dev/null; then
    # Criar bucket sempre em us-east-1
    aws s3api create-bucket \
        --bucket ${BUCKET_NAME} \
        --region us-east-1

    # Habilitar versionamento
    aws s3api put-bucket-versioning \
        --bucket ${BUCKET_NAME} \
        --versioning-configuration Status=Enabled
fi

# 2. Criar tabela DynamoDB se não existir (sempre em us-east-1)
echo "Verificando/criando tabela DynamoDB..."
if ! aws dynamodb describe-table --table-name ${DYNAMODB_TABLE} --region us-east-1 2>/dev/null; then
    aws dynamodb create-table \
        --table-name ${DYNAMODB_TABLE} \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
        --region us-east-1

    aws dynamodb wait table-exists --table-name ${DYNAMODB_TABLE} --region us-east-1
fi

# 3. Se forçar deleção do estado, limpar TUDO relacionado ao estado
if [ "${FORCE_DELETE_STATE}" = "true" ]; then
    echo "Forçando deleção do estado atual da região ${AWS_REGION}..."
    
    # Primeiro, remover TODOS os itens da tabela DynamoDB relacionados a esta região
    echo "Removendo todos os registros do DynamoDB para a região ${AWS_REGION}..."
    aws dynamodb scan \
        --table-name ${DYNAMODB_TABLE} \
        --region us-east-1 \
        --projection-expression "LockID" \
        --filter-expression "contains(LockID, :region)" \
        --expression-attribute-values '{":region":{"S":"regions/'${AWS_REGION}'"}}' \
        --query "Items[*].LockID.S" \
        --output text | while read -r lockid; do
        if [ ! -z "$lockid" ]; then
            aws dynamodb delete-item \
                --table-name ${DYNAMODB_TABLE} \
                --key "{\"LockID\": {\"S\": \"$lockid\"}}" \
                --region us-east-1
        fi
    done

    # Remover todas as versões do estado da região
    echo "Removendo versões do estado..."
    VERSIONS=$(aws s3api list-object-versions \
        --bucket ${BUCKET_NAME} \
        --prefix ${STATE_KEY} \
        --output json)

    # Deletar versões se existirem
    VERSIONS_TO_DELETE=$(echo $VERSIONS | jq -r '.Versions')
    if [ "$VERSIONS_TO_DELETE" != "null" ]; then
        echo $VERSIONS | jq -r '{Objects: [.Versions[] | {Key:.Key, VersionId:.VersionId}]}' | \
        aws s3api delete-objects \
            --bucket ${BUCKET_NAME} \
            --delete "$(cat -)" || true
    fi

    # Deletar marcadores de deleção se existirem
    DELETE_MARKERS=$(echo $VERSIONS | jq -r '.DeleteMarkers')
    if [ "$DELETE_MARKERS" != "null" ]; then
        echo $VERSIONS | jq -r '{Objects: [.DeleteMarkers[] | {Key:.Key, VersionId:.VersionId}]}' | \
        aws s3api delete-objects \
            --bucket ${BUCKET_NAME} \
            --delete "$(cat -)" || true
    fi

    # Aguardar um momento para garantir que as deleções foram processadas
    echo "Aguardando propagação das deleções..."
    sleep 10
fi

# 4. Remover diretório .terraform e arquivos de state locais
echo "Limpando arquivos locais..."
cd terraform/base
rm -rf .terraform*
rm -f terraform.tfstate*

echo "Iniciando setup da infraestrutura base..."

# Inicializar Terraform com backend configuration e forçar unlock se necessário
if [ "${FORCE_DELETE_STATE}" = "true" ]; then
    terraform init \
        -backend-config="bucket=${BUCKET_NAME}" \
        -backend-config="key=${STATE_KEY}" \
        -backend-config="region=us-east-1" \
        -backend-config="dynamodb_table=${DYNAMODB_TABLE}" \
        -force-copy

    terraform apply -auto-approve \
        -var="aws_region=${AWS_REGION}" \
        -lock=false  # Desabilitar lock temporariamente
else
    terraform init \
        -backend-config="bucket=${BUCKET_NAME}" \
        -backend-config="key=${STATE_KEY}" \
        -backend-config="region=us-east-1" \
        -backend-config="dynamodb_table=${DYNAMODB_TABLE}" \
        -force-copy

    terraform apply -auto-approve \
        -var="aws_region=${AWS_REGION}"
fi

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