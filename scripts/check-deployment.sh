#!/bin/bash
set -e

CLIENT=$1
ENVIRONMENT=$2
AWS_REGION=${3:-"us-east-2"}

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./check-deployment.sh <client_name> <environment> [aws_region]"
    exit 1
fi

echo "Verificando status do deployment para $CLIENT/$ENVIRONMENT na região $AWS_REGION..."

# Definir variáveis
ECS_CLUSTER="mautic-${CLIENT}-${ENVIRONMENT}-cluster"
ECS_SERVICE="mautic-${CLIENT}-${ENVIRONMENT}-service"
ALB_NAME="mautic-${CLIENT}-${ENVIRONMENT}-alb"

# Verificar status do cluster ECS
echo "Status do cluster ECS:"
aws ecs describe-clusters \
  --clusters "${ECS_CLUSTER}" \
  --region "${AWS_REGION}" \
  --query 'clusters[0].[clusterName,status,registeredContainerInstancesCount,runningTasksCount]' \
  --output table

# Verificar status do serviço ECS
echo "Status do serviço ECS:"
aws ecs describe-services \
  --cluster "${ECS_CLUSTER}" \
  --services "${ECS_SERVICE}" \
  --region "${AWS_REGION}" \
  --query 'services[0].[serviceName,status,desiredCount,runningCount,pendingCount]' \
  --output table

# Verificar tarefas em execução
echo "Tarefas em execução:"
TASKS=$(aws ecs list-tasks \
  --cluster "${ECS_CLUSTER}" \
  --service-name "${ECS_SERVICE}" \
  --region "${AWS_REGION}" \
  --query 'taskArns' \
  --output text)

if [ -n "$TASKS" ]; then
  aws ecs describe-tasks \
    --cluster "${ECS_CLUSTER}" \
    --tasks $TASKS \
    --region "${AWS_REGION}" \
    --query 'tasks[*].[taskArn,lastStatus,healthStatus,createdAt]' \
    --output table
else
  echo "Nenhuma tarefa em execução"
fi

# Verificar URL do load balancer
echo "URL da aplicação:"
ALB_DNS=$(aws elbv2 describe-load-balancers \
  --names "${ALB_NAME}" \
  --region "${AWS_REGION}" \
  --query 'LoadBalancers[0].DNSName' \
  --output text)

echo "http://${ALB_DNS}"

# Verificar status do target group
echo "Status do target group:"
TG_ARN=$(aws elbv2 describe-target-groups \
  --names "mautic-${CLIENT}-${ENVIRONMENT}-tg" \
  --region "${AWS_REGION}" \
  --query 'TargetGroups[0].TargetGroupArn' \
  --output text)

aws elbv2 describe-target-health \
  --target-group-arn "${TG_ARN}" \
  --region "${AWS_REGION}" \
  --query 'TargetHealthDescriptions[*].[Target.Id,TargetHealth.State,TargetHealth.Description]' \
  --output table

echo "Verificação concluída!" 