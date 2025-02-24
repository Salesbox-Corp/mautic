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

echo "Recriando infraestrutura do backend..."

# 1. Deletar e recriar bucket
echo "Recriando bucket S3..."

# Tentar remover objetos e versões de todos os caminhos possíveis
for KEY in "base/terraform.tfstate" "base/${AWS_REGION}/terraform.tfstate"; do
    echo "Limpando objetos do caminho: ${KEY}"
    
    # Remover todas as versões dos objetos
    aws s3api list-object-versions \
        --bucket ${BUCKET_NAME} \
        --prefix ${KEY} \
        --output json \
        --query '{Objects: Versions[].{Key:Key,VersionId:VersionId}}' | \
        aws s3api delete-objects \
            --bucket ${BUCKET_NAME} \
            --delete "$(cat -)" || true

    # Remover marcadores de deleção
    aws s3api list-object-versions \
        --bucket ${BUCKET_NAME} \
        --prefix ${KEY} \
        --output json \
        --query '{Objects: DeleteMarkers[].{Key:Key,VersionId:VersionId}}' | \
        aws s3api delete-objects \
            --bucket ${BUCKET_NAME} \
            --delete "$(cat -)" || true
done

# Agora podemos deletar o bucket
aws s3 rb "s3://${BUCKET_NAME}" --force || true

# Recriar o bucket
aws s3api create-bucket \
    --bucket ${BUCKET_NAME} \
    --region us-east-1

# Habilitar versionamento
aws s3api put-bucket-versioning \
    --bucket ${BUCKET_NAME} \
    --versioning-configuration Status=Enabled

# 2. Deletar e recriar tabela DynamoDB
echo "Recriando tabela DynamoDB..."
aws dynamodb delete-table --table-name ${DYNAMODB_TABLE} || true
aws dynamodb wait table-not-exists --table-name ${DYNAMODB_TABLE}

aws dynamodb create-table \
    --table-name ${DYNAMODB_TABLE} \
    --attribute-definitions AttributeName=LockID,AttributeType=S \
    --key-schema AttributeName=LockID,KeyType=HASH \
    --provisioned-throughput ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region us-east-1

aws dynamodb wait table-exists --table-name ${DYNAMODB_TABLE}

# Adicionar comando para limpar o digest do DynamoDB
aws dynamodb update-item \
    --table-name mautic-terraform-state-lock \
    --key '{"LockID": {"S": "base/terraform.tfstate"}}' \
    --update-expression "REMOVE Digest" \
    --region us-east-1  # Ajuste a região conforme necessário

# 3. Remover diretório .terraform e arquivos de state locais
echo "Limpando arquivos locais..."
cd terraform/base
rm -rf .terraform*
rm -f terraform.tfstate*

echo "Iniciando setup da infraestrutura base..."

# Antes de iniciar o Terraform, verificar se deve forçar deleção do estado
if [ "${FORCE_DELETE_STATE}" = "true" ]; then
    echo "Forçando deleção do estado atual..."
    aws s3 rm "s3://${BUCKET_NAME}/base/${AWS_REGION}/terraform.tfstate" || true
    aws s3 rm "s3://${BUCKET_NAME}/base/terraform.tfstate" || true

    # Limpar qualquer lock que possa existir
    aws dynamodb delete-item \
        --table-name ${DYNAMODB_TABLE} \
        --key '{"LockID": {"S": "base/terraform.tfstate"}}' \
        --region us-east-1 || true

    aws dynamodb delete-item \
        --table-name ${DYNAMODB_TABLE} \
        --key "{\"LockID\": {\"S\": \"base/${AWS_REGION}/terraform.tfstate\"}}" \
        --region us-east-1 || true
else
    echo "Mantendo estado atual..."
fi

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