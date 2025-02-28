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

# Forçar nova implantação do serviço
echo "Forçando nova implantação do serviço ECS..."
aws ecs update-service \
    --cluster "${ECS_CLUSTER}" \
    --service "${ECS_SERVICE}" \
    --force-new-deployment \
    --region "${AWS_REGION}"

# Aguardar até que a implantação seja concluída
echo "Aguardando conclusão da implantação..."
aws ecs wait services-stable --cluster "${ECS_CLUSTER}" --services "${ECS_SERVICE}" --region "${AWS_REGION}"

echo "Deploy concluído com sucesso!"
echo "Aplicação disponível em: https://$(aws elbv2 describe-load-balancers --names "mautic-${CLIENT}-${ENVIRONMENT}-alb" --region "${AWS_REGION}" --query 'LoadBalancers[0].DNSName' --output text)" 