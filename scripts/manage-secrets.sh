#!/bin/bash

function create_client_secrets() {
    CLIENT=$1
    ENVIRONMENT=$2

    # Gerar senhas
    DB_PASSWORD=$(openssl rand -base64 32)
    MAUTIC_ADMIN_PASSWORD=$(openssl rand -base64 16)
    
    # Criar secret no Secrets Manager com todas as credenciais do cliente
    aws secretsmanager create-secret \
        --name "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" \
        --secret-string "{
            \"db_password\": \"${DB_PASSWORD}\",
            \"mautic_admin_user\": \"admin\",
            \"mautic_admin_password\": \"${MAUTIC_ADMIN_PASSWORD}\",
            \"mautic_admin_email\": \"admin@${CLIENT}.com\"
        }"

    # Parâmetros não sensíveis no SSM
    aws ssm put-parameter \
        --name "/mautic/${CLIENT}/${ENVIRONMENT}/config/domain" \
        --value "${CLIENT}-${ENVIRONMENT}.mautic.exemplo.com" \
        --type "String" \
        --overwrite

    aws ssm put-parameter \
        --name "/mautic/${CLIENT}/${ENVIRONMENT}/config/email_from" \
        --value "mautic@${CLIENT}.com" \
        --type "String" \
        --overwrite
} 