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