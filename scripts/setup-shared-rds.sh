#!/bin/bash

# Criar RDS compartilhado
cd terraform/shared
terraform init
terraform apply -auto-approve

# Obter outputs do Terraform
RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
RDS_USERNAME=$(terraform output -raw rds_username)
RDS_PASSWORD=$(terraform output -raw rds_password)

# Salvar credenciais no Secrets Manager
aws secretsmanager create-secret \
    --name "/mautic/shared/rds/master" \
    --secret-string "{
        \"username\": \"${RDS_USERNAME}\",
        \"password\": \"${RDS_PASSWORD}\"
    }"

# Salvar endpoint no SSM (não é sensível)
aws ssm put-parameter \
    --name "/mautic/shared/rds/endpoint" \
    --value "${RDS_ENDPOINT}" \
    --type "String" \
    --overwrite

# Aguardar RDS ficar disponível
echo "Aguardando RDS ficar disponível..."
aws rds wait db-instance-available --db-instance-identifier mautic-shared-db

echo "RDS compartilhado configurado com sucesso" 