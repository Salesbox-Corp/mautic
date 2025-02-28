#!/bin/bash
set -e

# Funções auxiliares
process_admin_credentials() {
    IFS=',' read -r email password firstname lastname <<< "$1"
    export MAUTIC_ADMIN_EMAIL="$email"
    export MAUTIC_ADMIN_PASSWORD="$password"
    export MAUTIC_ADMIN_FIRSTNAME="$firstname"
    export MAUTIC_ADMIN_LASTNAME="$lastname"
}

process_mailer_config() {
    IFS=',' read -r name email <<< "$1"
    export MAUTIC_ADMIN_FROM_NAME="$name"
    export MAUTIC_ADMIN_FROM_EMAIL="$email"
}

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

# Criar nova task definition usando a atual como base, apenas atualizando a imagem
echo "Criando nova task definition..."
NEW_TASK_DEFINITION=$(echo "$TASK_DEFINITION" | jq --arg IMAGE "${ECR_REPOSITORY_URI}:${VERSION}" '.taskDefinition | .containerDefinitions[0].image = $IMAGE | del(.taskDefinitionArn, .revision, .status, .requiresAttributes, .compatibilities, .registeredAt, .registeredBy)' | aws ecs register-task-definition --region "${AWS_REGION}" --cli-input-json '{
    "family": "'${TASK_FAMILY}'",
    "taskRoleArn": "'$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.taskRoleArn')'",
    "executionRoleArn": "'$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.executionRoleArn')'",
    "networkMode": "'$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.networkMode')'",
    "containerDefinitions": '$(echo "$TASK_DEFINITION" | jq '.taskDefinition.containerDefinitions | map(if .name == "mautic" then . + {"image": "'${ECR_REPOSITORY_URI}:${VERSION}'"} else . end)')',
    "volumes": '$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.volumes')',
    "requiresCompatibilities": ["FARGATE"],
    "cpu": "'$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.cpu')'",
    "memory": "'$(echo "$TASK_DEFINITION" | jq -r '.taskDefinition.memory')'"
}' --query 'taskDefinition.taskDefinitionArn' --output text)

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