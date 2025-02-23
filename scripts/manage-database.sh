#!/bin/bash

function create_client_database() {
    CLIENT=$1
    ENVIRONMENT=$2

    # Obter credenciais do RDS master
    RDS_CREDENTIALS=$(aws secretsmanager get-secret-value \
        --secret-id "/mautic/shared/rds/master" \
        --query 'SecretString' --output text)
    
    RDS_ENDPOINT=$(aws ssm get-parameter --name "/mautic/shared/rds/endpoint" --query "Parameter.Value" --output text)
    MASTER_USER=$(echo $RDS_CREDENTIALS | jq -r '.username')
    MASTER_PASSWORD=$(echo $RDS_CREDENTIALS | jq -r '.password')

    # Obter credenciais do cliente
    CLIENT_CREDENTIALS=$(aws secretsmanager get-secret-value \
        --secret-id "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" \
        --query 'SecretString' --output text)
    
    DB_PASSWORD=$(echo $CLIENT_CREDENTIALS | jq -r '.db_password')
    DB_NAME="mautic_${CLIENT}_${ENVIRONMENT}"
    DB_USER="${DB_NAME}_user"

    # Criar banco e usuário
    mysql -h $RDS_ENDPOINT -u $MASTER_USER -p${MASTER_PASSWORD} <<EOF
    CREATE DATABASE IF NOT EXISTS ${DB_NAME} CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
    CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
    GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
    FLUSH PRIVILEGES;
EOF

    # Verificar se o banco foi criado
    DB_EXISTS=$(mysql -h $RDS_ENDPOINT -u $MASTER_USER -p${MASTER_PASSWORD} \
        -e "SHOW DATABASES LIKE '${DB_NAME}';" | grep ${DB_NAME} || true)

    if [ -z "$DB_EXISTS" ]; then
        echo "Erro: Falha ao criar banco de dados ${DB_NAME}"
        exit 1
    fi

    echo "Banco de dados ${DB_NAME} criado com sucesso"

    # Salvar informações do banco no SSM
    aws ssm put-parameter \
        --name "/mautic/${CLIENT}/${ENVIRONMENT}/database/name" \
        --value "${DB_NAME}" \
        --type "String" \
        --overwrite

    aws ssm put-parameter \
        --name "/mautic/${CLIENT}/${ENVIRONMENT}/database/user" \
        --value "${DB_USER}" \
        --type "String" \
        --overwrite
} 