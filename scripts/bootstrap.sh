#!/bin/bash

# Obter ID da conta AWS
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"

echo "Usando bucket: $BUCKET_NAME"

# Verificar se o bucket já existe e se temos acesso
if ! aws s3api head-bucket --bucket $BUCKET_NAME 2>/dev/null; then
    echo "Criando bucket para Terraform state..."
    # Criar bucket sempre em us-east-1
    aws s3api create-bucket \
        --bucket $BUCKET_NAME \
        --region us-east-1  # Região fixa para o bucket de state

    echo "Configurando bucket..."
    
    # Habilitar versionamento
    aws s3api put-bucket-versioning \
        --bucket $BUCKET_NAME \
        --versioning-configuration Status=Enabled

    # Habilitar criptografia
    aws s3api put-bucket-encryption \
        --bucket $BUCKET_NAME \
        --server-side-encryption-configuration '{
            "Rules": [
                {
                    "ApplyServerSideEncryptionByDefault": {
                        "SSEAlgorithm": "AES256"
                    }
                }
            ]
        }'

    # Bloquear acesso público
    aws s3api put-public-access-block \
        --bucket $BUCKET_NAME \
        --public-access-block-configuration '{
            "BlockPublicAcls": true,
            "IgnorePublicAcls": true,
            "BlockPublicPolicy": true,
            "RestrictPublicBuckets": true
        }'
else
    echo "Bucket $BUCKET_NAME já existe, verificando acesso..."
    # Testar permissões
    if ! aws s3 ls s3://$BUCKET_NAME >/dev/null 2>&1; then
        echo "Erro: Não temos permissão para acessar o bucket $BUCKET_NAME"
        exit 1
    fi
fi

# Verificar se a tabela DynamoDB já existe
TABLE_EXISTS=$(aws dynamodb describe-table --table-name mautic-terraform-lock 2>&1 || true)

if [[ -n "$TABLE_EXISTS" ]]; then
    echo "Criando tabela DynamoDB para lock..."
    aws dynamodb create-table \
        --table-name mautic-terraform-lock \
        --attribute-definitions AttributeName=LockID,AttributeType=S \
        --key-schema AttributeName=LockID,KeyType=HASH \
        --billing-mode PAY_PER_REQUEST
fi

echo "Infraestrutura de backend configurada com sucesso!" 