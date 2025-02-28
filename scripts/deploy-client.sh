#!/bin/bash
set -e

CLIENT=$1
ENVIRONMENT=$2
VERSION=${3:-latest}
AWS_REGION=${4:-"us-east-2"}

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./deploy-client.sh <client_name> <environment> [version] [aws_region]"
    exit 1
fi

echo "Iniciando deploy para $CLIENT/$ENVIRONMENT na região $AWS_REGION..."

# Definir variáveis
ECR_REPOSITORY="mautic-${CLIENT}-${ENVIRONMENT}"
ECS_CLUSTER="mautic-${CLIENT}-${ENVIRONMENT}-cluster"
ECS_SERVICE="mautic-${CLIENT}-${ENVIRONMENT}-service"
TASK_FAMILY="mautic-${CLIENT}-${ENVIRONMENT}-task"

# Obter o ID da conta AWS
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
ECR_REPOSITORY_URI="${ECR_REGISTRY}/${ECR_REPOSITORY}"

echo "Verificando se o repositório ECR existe..."
if ! aws ecr describe-repositories --repository-names "${ECR_REPOSITORY}" --region "${AWS_REGION}" >/dev/null 2>&1; then
    echo "Erro: Repositório ECR ${ECR_REPOSITORY} não encontrado"
    echo "Verifique se a infraestrutura foi criada corretamente"
    exit 1
fi

# Fazer login no ECR
echo "Fazendo login no ECR..."
aws ecr get-login-password --region "${AWS_REGION}" | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

# Construir a imagem Docker
echo "Construindo imagem Docker..."
docker build -t "${ECR_REPOSITORY_URI}:${VERSION}" -t "${ECR_REPOSITORY_URI}:latest" .

# Enviar a imagem para o ECR
echo "Enviando imagem para o ECR..."
docker push "${ECR_REPOSITORY_URI}:${VERSION}"
docker push "${ECR_REPOSITORY_URI}:latest"

# Obter a task definition atual
echo "Obtendo task definition atual..."
TASK_DEFINITION=$(aws ecs describe-task-definition --task-definition "${TASK_FAMILY}" --region "${AWS_REGION}")
TASK_ROLE_ARN=$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.taskRoleArn')
EXECUTION_ROLE_ARN=$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.executionRoleArn')
NETWORK_MODE=$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.networkMode')
CPU=$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.cpu')
MEMORY=$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.memory')

# Preparar as variáveis de ambiente
ENVIRONMENT_VARS=$(cat <<EOF
[
  {"name": "MAUTIC_DB_HOST", "value": "$MAUTIC_DB_HOST"},
  {"name": "MAUTIC_DB_PORT", "value": "$MAUTIC_DB_PORT"},
  {"name": "MAUTIC_DB_NAME", "value": "$MAUTIC_DB_NAME"},
  {"name": "MAUTIC_DB_USER", "value": "$MAUTIC_DB_USER"},
  {"name": "MAUTIC_DB_PASSWORD", "value": "$MAUTIC_DB_PASSWORD"},
  {"name": "MAUTIC_URL", "value": "$MAUTIC_URL"}
EOF
)

# Adicionar variáveis condicionais
if [ ! -z "$MAUTIC_CUSTOM_LOGO_URL" ]; then
    ENVIRONMENT_VARS=$(echo "$ENVIRONMENT_VARS" | jq '. += [{"name": "MAUTIC_CUSTOM_LOGO_URL", "value": "'"$MAUTIC_CUSTOM_LOGO_URL"'"}]')
fi

if [ "$IS_FIRST_INSTALL" = "true" ]; then
    ENVIRONMENT_VARS=$(echo "$ENVIRONMENT_VARS" | jq '. += [
        {"name": "MAUTIC_ADMIN_EMAIL", "value": "'"$MAUTIC_ADMIN_EMAIL"'"},
        {"name": "MAUTIC_ADMIN_PASSWORD", "value": "'"$MAUTIC_ADMIN_PASSWORD"'"},
        {"name": "MAUTIC_ADMIN_FIRSTNAME", "value": "'"$MAUTIC_ADMIN_FIRSTNAME"'"},
        {"name": "MAUTIC_ADMIN_LASTNAME", "value": "'"$MAUTIC_ADMIN_LASTNAME"'"},
        {"name": "MAUTIC_ADMIN_FROM_NAME", "value": "'"$MAUTIC_ADMIN_FROM_NAME"'"},
        {"name": "MAUTIC_ADMIN_FROM_EMAIL", "value": "'"$MAUTIC_ADMIN_FROM_EMAIL"'"}
    ]')
fi

ENVIRONMENT_VARS="$ENVIRONMENT_VARS]"

# Criar nova task definition
echo "Criando nova task definition..."
NEW_TASK_DEFINITION=$(aws ecs register-task-definition \
    --family "${TASK_FAMILY}" \
    --task-role-arn "${TASK_ROLE_ARN}" \
    --execution-role-arn "${EXECUTION_ROLE_ARN}" \
    --network-mode "${NETWORK_MODE}" \
    --cpu "${CPU}" \
    --memory "${MEMORY}" \
    --requires-compatibilities "FARGATE" \
    --container-definitions "[
        {
            \"name\": \"${ECR_REPOSITORY}\",
            \"image\": \"${ECR_REPOSITORY_URI}:${VERSION}\",
            \"essential\": true,
            \"environment\": ${ENVIRONMENT_VARS},
            \"portMappings\": [
                {
                    \"containerPort\": 80,
                    \"protocol\": \"tcp\"
                }
            ],
            \"logConfiguration\": {
                \"logDriver\": \"awslogs\",
                \"options\": {
                    \"awslogs-group\": \"/ecs/${TASK_FAMILY}\",
                    \"awslogs-region\": \"${AWS_REGION}\",
                    \"awslogs-stream-prefix\": \"ecs\"
                }
            }
        }
    ]" \
    --region "${AWS_REGION}" \
    --query 'taskDefinition.taskDefinitionArn' \
    --output text)

# Atualizar o serviço com a nova task definition
echo "Atualizando serviço ECS com nova task definition..."
aws ecs update-service \
    --cluster "${ECS_CLUSTER}" \
    --service "${ECS_SERVICE}" \
    --task-definition "${NEW_TASK_DEFINITION}" \
    --force-new-deployment \
    --region "${AWS_REGION}"

# Aguardar até que a implantação seja concluída
echo "Aguardando conclusão da implantação..."
aws ecs wait services-stable --cluster "${ECS_CLUSTER}" --services "${ECS_SERVICE}" --region "${AWS_REGION}"

echo "Deploy concluído com sucesso!"
echo "Aplicação disponível em: https://$(aws elbv2 describe-load-balancers --names "mautic-${CLIENT}-${ENVIRONMENT}-alb" --region "${AWS_REGION}" --query 'LoadBalancers[0].DNSName' --output text)" 