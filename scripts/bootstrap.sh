#!/bin/bash

# Verificar se o bucket já existe
BUCKET_EXISTS=$(aws s3api head-bucket --bucket mautic-terraform-state 2>&1 || true)

if [[ -n "$BUCKET_EXISTS" ]]; then
    echo "Criando bucket para Terraform state..."
    aws s3api create-bucket \
        --bucket mautic-terraform-state \
        --region us-east-1

    # Habilitar versionamento
    aws s3api put-bucket-versioning \
        --bucket mautic-terraform-state \
        --versioning-configuration Status=Enabled

    # Habilitar criptografia
    aws s3api put-bucket-encryption \
        --bucket mautic-terraform-state \
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
        --bucket mautic-terraform-state \
        --public-access-block-configuration '{
            "BlockPublicAcls": true,
            "IgnorePublicAcls": true,
            "BlockPublicPolicy": true,
            "RestrictPublicBuckets": true
        }'
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