#!/bin/bash

CLIENT=$1
ENVIRONMENT=$2
AWS_REGION=${3:-"us-east-2"}
CLEAN_RESOURCES=${4:-"false"}
CUSTOM_LOGO_URL=${5:-""}
SUBDOMAIN=${6:-""}

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ] || [ -z "$SUBDOMAIN" ]; then
    echo "Usage: ./setup-client.sh <client_name> <environment> [aws_region] [clean_resources] [custom_logo_url] <subdomain>"
    echo "  clean_resources: 'true' para remover recursos existentes antes de criar novos (default: false)"
    echo "  custom_logo_url: URL do logo personalizado (opcional)"
    echo "  subdomain: Subdomínio para o cliente (obrigatório, será criado como: SUBDOMINIO.salesbox.com.br)"
    exit 1
fi

CLIENT_DIR="terraform/environments/clients/${CLIENT}/${ENVIRONMENT}"
STATE_KEY="regions/${AWS_REGION}/clients/${CLIENT}/${ENVIRONMENT}/terraform.tfstate"

echo "Iniciando setup para ${CLIENT}/${ENVIRONMENT} na região ${AWS_REGION}..."

# Função para limpar recursos existentes
clean_existing_resources() {
    echo "Limpando recursos existentes para ${CLIENT}/${ENVIRONMENT}..."
    
    # Verificar e remover repositório ECR
    ECR_REPO="mautic-${CLIENT}-${ENVIRONMENT}"
    if aws ecr describe-repositories --repository-names "${ECR_REPO}" >/dev/null 2>&1; then
        echo "Removendo repositório ECR ${ECR_REPO}..."
        
        # Primeiro, remover todas as imagens
        IMAGES=$(aws ecr list-images --repository-name "${ECR_REPO}" --query 'imageIds[*]' --output json)
        if [ "$(echo $IMAGES | jq 'length')" -gt 0 ]; then
            echo "Removendo imagens do repositório..."
            aws ecr batch-delete-image --repository-name "${ECR_REPO}" --image-ids "$(echo $IMAGES)" || true
        fi
        
        # Depois, remover o repositório
        aws ecr delete-repository --repository-name "${ECR_REPO}" --force || true
    fi
    
    # Verificar e remover secrets
    if aws secretsmanager describe-secret --secret-id "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" >/dev/null 2>&1; then
        echo "Removendo secret /mautic/${CLIENT}/${ENVIRONMENT}/credentials..."
        aws secretsmanager delete-secret --secret-id "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" --force-delete-without-recovery || true
    fi
    
    # Remover parâmetros SSM
    echo "Removendo parâmetros SSM..."
    aws ssm delete-parameters --names \
        "/mautic/${CLIENT}/${ENVIRONMENT}/config/domain" \
        "/mautic/${CLIENT}/${ENVIRONMENT}/config/email_from" || true
    
    # Verificar e remover banco de dados
    DB_NAME="mautic_${CLIENT}_${ENVIRONMENT}"
    DB_USER="${DB_NAME}_user"
    
    # Obter endpoint RDS
    RDS_ENDPOINT=$(aws ssm get-parameter \
      --name "/mautic/${AWS_REGION}/shared/rds/endpoint" \
      --region "${AWS_REGION}" \
      --query "Parameter.Value" \
      --output text)
    
    # Obter credenciais RDS Master
    RDS_MASTER_SECRET=$(aws secretsmanager get-secret-value \
      --secret-id "/mautic/${AWS_REGION}/shared/rds/master" \
      --region "${AWS_REGION}" \
      --query 'SecretString' \
      --output text)
    
    MASTER_USER=$(echo $RDS_MASTER_SECRET | jq -r '.username')
    MASTER_PASSWORD=$(echo $RDS_MASTER_SECRET | jq -r '.password')
    
    # Garantir que o endpoint está no formato correto
    RDS_ENDPOINT=$(echo $RDS_ENDPOINT | sed 's|^mysql://||')
    RDS_ENDPOINT=$(echo $RDS_ENDPOINT | sed 's/:[0-9]*$//')
    
    echo "Removendo banco de dados e usuário..."
    mysql -h "${RDS_ENDPOINT}" \
        -u "${MASTER_USER}" \
        -p"${MASTER_PASSWORD}" \
        --protocol=TCP <<EOF
DROP DATABASE IF EXISTS ${DB_NAME};
DROP USER IF EXISTS '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
    
    # Verificar e remover recursos ECS
    CLUSTER_NAME="mautic-${CLIENT}-${ENVIRONMENT}-cluster"
    SERVICE_NAME="mautic-${CLIENT}-${ENVIRONMENT}-service"
    
    # Verificar se o serviço existe e removê-lo
    if aws ecs describe-services --cluster "${CLUSTER_NAME}" --services "${SERVICE_NAME}" --query 'services[0].status' --output text 2>/dev/null | grep -q ACTIVE; then
        echo "Removendo serviço ECS ${SERVICE_NAME}..."
        aws ecs update-service --cluster "${CLUSTER_NAME}" --service "${SERVICE_NAME}" --desired-count 0 || true
        aws ecs delete-service --cluster "${CLUSTER_NAME}" --service "${SERVICE_NAME}" --force || true
        
        # Esperar até que o serviço seja removido
        echo "Aguardando remoção do serviço..."
        aws ecs wait services-inactive --cluster "${CLUSTER_NAME}" --services "${SERVICE_NAME}" || true
    fi
    
    # Verificar se o cluster existe e removê-lo
    if aws ecs describe-clusters --clusters "${CLUSTER_NAME}" --query 'clusters[0].status' --output text 2>/dev/null | grep -q ACTIVE; then
        echo "Removendo cluster ECS ${CLUSTER_NAME}..."
        aws ecs delete-cluster --cluster "${CLUSTER_NAME}" || true
    fi
    
    # Verificar e remover load balancer
    LB_NAME="mautic-${CLIENT}-${ENVIRONMENT}-alb"
    LB_ARN=$(aws elbv2 describe-load-balancers --names "${LB_NAME}" --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || echo "")
    
    if [ "$LB_ARN" != "None" ] && [ ! -z "$LB_ARN" ]; then
        echo "Removendo load balancer ${LB_NAME}..."
        
        # Primeiro, remover listeners
        LISTENERS=$(aws elbv2 describe-listeners --load-balancer-arn "${LB_ARN}" --query 'Listeners[*].ListenerArn' --output text)
        for listener in $LISTENERS; do
            echo "Removendo listener ${listener}..."
            aws elbv2 delete-listener --listener-arn "${listener}" || true
        done
        
        # Depois, remover target groups
        TGS=$(aws elbv2 describe-target-groups --load-balancer-arn "${LB_ARN}" --query 'TargetGroups[*].TargetGroupArn' --output text)
        for tg in $TGS; do
            echo "Removendo target group ${tg}..."
            aws elbv2 delete-target-group --target-group-arn "${tg}" || true
        done
        
        # Finalmente, remover o load balancer
        aws elbv2 delete-load-balancer --load-balancer-arn "${LB_ARN}" || true
        
        # Aguardar remoção do load balancer
        echo "Aguardando remoção do load balancer..."
        sleep 30
    fi
    
    echo "Limpeza de recursos concluída"
}

# Função para detectar recursos existentes
detect_existing_resources() {
    echo "Detectando recursos existentes para ${CLIENT}/${ENVIRONMENT}..."
    
    # Verificar repositório ECR
    ECR_REPO="mautic-${CLIENT}-${ENVIRONMENT}"
    if aws ecr describe-repositories --repository-names "${ECR_REPO}" >/dev/null 2>&1; then
        echo "Repositório ECR ${ECR_REPO} encontrado"
        ECR_EXISTS="true"
        ECR_REPO_URL=$(aws ecr describe-repositories \
            --repository-names "${ECR_REPO}" \
            --query 'repositories[0].repositoryUri' \
            --output text)
    else
        echo "Repositório ECR ${ECR_REPO} não encontrado"
        ECR_EXISTS="false"
    fi
    
    # Verificar cluster ECS
    CLUSTER_NAME="mautic-${CLIENT}-${ENVIRONMENT}-cluster"
    if aws ecs describe-clusters --clusters "${CLUSTER_NAME}" --query 'clusters[0].status' --output text 2>/dev/null | grep -q ACTIVE; then
        echo "Cluster ECS ${CLUSTER_NAME} encontrado"
        CLUSTER_EXISTS="true"
    else
        echo "Cluster ECS ${CLUSTER_NAME} não encontrado"
        CLUSTER_EXISTS="false"
    fi
    
    # Verificar banco de dados
    DB_NAME="mautic_${CLIENT}_${ENVIRONMENT}"
    RDS_ENDPOINT=$(aws ssm get-parameter \
      --name "/mautic/${AWS_REGION}/shared/rds/endpoint" \
      --region "${AWS_REGION}" \
      --query "Parameter.Value" \
      --output text)
    
    RDS_MASTER_SECRET=$(aws secretsmanager get-secret-value \
      --secret-id "/mautic/${AWS_REGION}/shared/rds/master" \
      --region "${AWS_REGION}" \
      --query 'SecretString' \
      --output text)
    
    MASTER_USER=$(echo $RDS_MASTER_SECRET | jq -r '.username')
    MASTER_PASSWORD=$(echo $RDS_MASTER_SECRET | jq -r '.password')
    
    # Garantir que o endpoint está no formato correto
    RDS_ENDPOINT=$(echo $RDS_ENDPOINT | sed 's|^mysql://||')
    RDS_ENDPOINT=$(echo $RDS_ENDPOINT | sed 's/:[0-9]*$//')
    
    DB_EXISTS=$(mysql -h "${RDS_ENDPOINT}" \
        -u "${MASTER_USER}" \
        -p"${MASTER_PASSWORD}" \
        --protocol=TCP \
        -e "SHOW DATABASES LIKE '${DB_NAME}';" | grep ${DB_NAME} || true)
    
    if [ -z "$DB_EXISTS" ]; then
        echo "Banco de dados ${DB_NAME} não encontrado"
        DB_EXISTS="false"
    else
        echo "Banco de dados ${DB_NAME} encontrado"
        DB_EXISTS="true"
    fi
    
    # Verificar secrets
    if aws secretsmanager describe-secret --secret-id "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" >/dev/null 2>&1; then
        echo "Secret /mautic/${CLIENT}/${ENVIRONMENT}/credentials encontrado"
        SECRET_EXISTS="true"
    else
        echo "Secret /mautic/${CLIENT}/${ENVIRONMENT}/credentials não encontrado"
        SECRET_EXISTS="false"
    fi
    
    # Resumo dos recursos encontrados
    echo "Resumo dos recursos existentes:"
    echo "- Repositório ECR: ${ECR_EXISTS}"
    echo "- Cluster ECS: ${CLUSTER_EXISTS}"
    echo "- Banco de dados: ${DB_EXISTS}"
    echo "- Secret: ${SECRET_EXISTS}"
}

# Verificar se deve limpar recursos existentes
if [ "${CLEAN_RESOURCES}" = "true" ]; then
    echo "Modo de limpeza ativado. Removendo recursos existentes antes de prosseguir..."
    clean_existing_resources
    # Após limpeza, todos os recursos são considerados novos
    ECR_EXISTS="false"
    CLUSTER_EXISTS="false"
    DB_EXISTS="false"
    SECRET_EXISTS="false"
else
    # Detectar recursos existentes
    detect_existing_resources
fi

# Obter informações da infra compartilhada da região específica
echo "Obtendo informações da infraestrutura compartilhada na região ${AWS_REGION}..."

# RDS Endpoint
RDS_ENDPOINT=$(aws ssm get-parameter \
  --name "/mautic/${AWS_REGION}/shared/rds/endpoint" \
  --region "${AWS_REGION}" \
  --query "Parameter.Value" \
  --output text)

# Verificar se o secret existe antes de tentar usar
echo "Verificando secret do RDS master..."
if ! aws secretsmanager describe-secret \
  --secret-id "/mautic/${AWS_REGION}/shared/rds/master" \
  --region "${AWS_REGION}" >/dev/null 2>&1; then
  echo "Erro: Secret do RDS master não encontrado em /mautic/${AWS_REGION}/shared/rds/master"
  echo "Verifique se a infraestrutura base foi criada corretamente na região ${AWS_REGION}"
  exit 1
fi

# Credenciais RDS Master
RDS_MASTER_SECRET=$(aws secretsmanager get-secret-value \
  --secret-id "/mautic/${AWS_REGION}/shared/rds/master" \
  --region "${AWS_REGION}" \
  --query 'SecretString' \
  --output text)

MASTER_USER=$(echo $RDS_MASTER_SECRET | jq -r '.username')
MASTER_PASSWORD=$(echo $RDS_MASTER_SECRET | jq -r '.password')

# Gerar senhas para o cliente apenas se não existirem
if [ "${SECRET_EXISTS}" = "false" ]; then
    echo "Gerando novas credenciais para o cliente..."
    DB_PASSWORD=$(openssl rand -base64 32)
    MAUTIC_ADMIN_PASSWORD=$(openssl rand -base64 16)
    
    # Criar secret com credenciais do cliente
    echo "Criando credenciais do cliente..."
    aws secretsmanager create-secret \
        --name "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" \
        --secret-string "{
            \"db_password\": \"${DB_PASSWORD}\",
            \"mautic_admin_user\": \"admin\",
            \"mautic_admin_password\": \"${MAUTIC_ADMIN_PASSWORD}\",
            \"mautic_admin_email\": \"admin@${CLIENT}.com\"
        }"
else
    echo "Usando credenciais existentes do cliente..."
    CLIENT_SECRET=$(aws secretsmanager get-secret-value \
      --secret-id "/mautic/${CLIENT}/${ENVIRONMENT}/credentials" \
      --query 'SecretString' \
      --output text)
    
    DB_PASSWORD=$(echo $CLIENT_SECRET | jq -r '.db_password')
fi

# Criar/atualizar parâmetros de configuração
echo "Atualizando parâmetros de configuração..."
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

# Criar banco de dados do cliente se não existir
echo "Verificando banco de dados..."
DB_NAME="mautic_${CLIENT}_${ENVIRONMENT}"
DB_USER="${DB_NAME}_user"

# Validar endpoint do RDS antes de prosseguir
if [ -z "$RDS_ENDPOINT" ]; then
  echo "Erro: Endpoint do RDS não encontrado no SSM Parameter Store"
  exit 1
fi

# Garantir que o endpoint está no formato correto
# Remover protocolo se existir
RDS_ENDPOINT=$(echo $RDS_ENDPOINT | sed 's|^mysql://||')
# Remover porta se existir
RDS_ENDPOINT=$(echo $RDS_ENDPOINT | sed 's/:[0-9]*$//')

echo "Usando endpoint RDS: ${RDS_ENDPOINT}"

# Antes de criar o banco, verificar se consegue conectar ao RDS
echo "Verificando conexão com RDS..."
if ! mysql -h "${RDS_ENDPOINT}" \
          -u "${MASTER_USER}" \
          -p"${MASTER_PASSWORD}" \
          --protocol=TCP \
          -P 3306 \
          -e "SELECT 1;" > /dev/null 2>&1; then
  echo "Erro: Não foi possível conectar ao RDS em ${RDS_ENDPOINT}"
  echo "Detalhes da conexão (sem senha):"
  echo "Host: ${RDS_ENDPOINT}"
  echo "User: ${MASTER_USER}"
  echo "Protocol: TCP"
  echo "Port: 3306"
  exit 1
fi

# Criar banco de dados se não existir
if [ "${DB_EXISTS}" = "false" ]; then
    echo "Criando banco de dados..."
    mysql -h "${RDS_ENDPOINT}" \
        -u "${MASTER_USER}" \
        -p"${MASTER_PASSWORD}" \
        --protocol=TCP <<EOF
CREATE DATABASE IF NOT EXISTS ${DB_NAME};
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON ${DB_NAME}.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
EOF
else
    echo "Banco de dados já existe, mantendo configuração atual"
    
    # Atualizar senha do usuário se necessário
    echo "Atualizando senha do usuário do banco de dados..."
    mysql -h "${RDS_ENDPOINT}" \
        -u "${MASTER_USER}" \
        -p"${MASTER_PASSWORD}" \
        --protocol=TCP <<EOF
ALTER USER '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
FLUSH PRIVILEGES;
EOF
fi

# Verificar/criar repositório ECR
echo "Verificando repositório ECR..."
ECR_REPO="mautic-${CLIENT}-${ENVIRONMENT}"
if [ "${ECR_EXISTS}" = "false" ]; then
    echo "Criando repositório ECR..."
    aws ecr create-repository \
        --repository-name "${ECR_REPO}" \
        --image-scanning-configuration scanOnPush=true
    
    ECR_EXISTS="true"
    ECR_REPO_URL=$(aws ecr describe-repositories \
        --repository-names "${ECR_REPO}" \
        --query 'repositories[0].repositoryUri' \
        --output text)
else
    echo "Repositório ECR já existe"
fi

# Obter URL do repositório ECR
if [ -z "${ECR_REPO_URL}" ]; then
    ECR_REPO_URL=$(aws ecr describe-repositories \
        --repository-names "${ECR_REPO}" \
        --query 'repositories[0].repositoryUri' \
        --output text)
fi

# Preparar diretório Terraform
echo "Preparando configuração Terraform..."
mkdir -p "${CLIENT_DIR}"

# Exportar variáveis para o template
export CLIENT ENVIRONMENT AWS_REGION RDS_ENDPOINT DB_NAME DB_USER ECR_REPO_URL ECR_EXISTS
envsubst < terraform/templates/client-minimal/terraform.tfvars > "${CLIENT_DIR}/terraform.tfvars"

# Copiar arquivos do template
cp terraform/templates/client-minimal/main.tf "${CLIENT_DIR}/"
sed -i '/^provider "aws" {/,/^}/d' "${CLIENT_DIR}/main.tf"
cp terraform/templates/client-minimal/variables.tf "${CLIENT_DIR}/"

# Remover qualquer referência ao módulo shared_vpc
find "${CLIENT_DIR}" -type f -name "*.tf" -exec sed -i '/module.*"shared_vpc"/,/^}/d' {} \;

# Criar provider.tf e backend.tf
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
BUCKET_NAME="mautic-terraform-state-${AWS_ACCOUNT_ID}"

# Criar provider.tf
cat > "${CLIENT_DIR}/provider.tf" <<EOF
terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

# Provider principal para a região do cliente
provider "aws" {
  region = var.aws_region
}

# Provider para recursos que precisam estar em us-east-1 (como ACM)
provider "aws" {
  alias  = "us-east-1"
  region = "us-east-1"
}
EOF

# Criar backend.tf
cat > "${CLIENT_DIR}/backend.tf" <<EOF
terraform {
  backend "s3" {
    bucket         = "${BUCKET_NAME}"
    key            = "${STATE_KEY}"
    region         = "us-east-1"
    dynamodb_table = "mautic-terraform-lock"
    encrypt        = true
  }
}
EOF

# Função para remover locks do Terraform
remove_terraform_lock() {
    local lock_id="$1"
    local table_name="mautic-terraform-lock"
    local state_path="$2"

    echo "Tentando remover lock pendente..."
    aws dynamodb delete-item \
        --table-name "$table_name" \
        --key "{\"LockID\": {\"S\": \"$state_path\"}}" \
        --region "us-east-1"
    
    echo "Lock removido com sucesso"
}

# Atualizar a parte do Terraform para incluir tratamento de lock
cd "${CLIENT_DIR}"
terraform init

echo "Planejando alterações..."
if ! terraform plan -out=tfplan 2>terraform.err; then
    if grep -q "Error acquiring the state lock" terraform.err; then
        # Extrair informações do lock
        LOCK_PATH=$(grep "Path:" terraform.err | awk '{print $2}')
        
        echo "Lock detectado no estado. Tentando remover..."
        remove_terraform_lock "$LOCK_ID" "$LOCK_PATH"
        
        # Tentar novamente com lock removido
        echo "Tentando plan novamente..."
        if ! terraform plan -out=tfplan; then
            echo "Erro no planejamento do Terraform mesmo após remover lock"
            exit 1
        fi
    else
        cat terraform.err
        echo "Erro no planejamento do Terraform"
        exit 1
    fi
fi

echo "Aplicando alterações..."
if ! terraform apply tfplan; then
    echo "Erro na aplicação do Terraform"
    exit 1
fi

# Verificar se o cluster foi criado
CLUSTER_NAME="mautic-${CLIENT}-${ENVIRONMENT}-cluster"
if ! aws ecs describe-clusters --clusters $CLUSTER_NAME --query 'clusters[0].status' --output text | grep -q ACTIVE; then
  echo "Erro: Cluster ECS não foi criado corretamente"
  exit 1
fi

echo "Setup concluído para ${CLIENT}/${ENVIRONMENT}"

# Criar arquivo terraform.tfvars
cat > ${CLIENT_DIR}/terraform.tfvars <<EOF
client      = "${CLIENT}"
environment = "${ENVIRONMENT}"
aws_region  = "${AWS_REGION}"
project     = "mautic"

# Configurações do banco de dados
db_host     = "${RDS_ENDPOINT}"
db_name     = "${DB_NAME}"
db_username = "${DB_USER}"

# Logo personalizado
custom_logo_url = "${CUSTOM_LOGO_URL}"

# Configurações de domínio
domain         = "salesbox.com.br"
subdomain      = "${SUBDOMAIN}"
hosted_zone_id = "Z030834419BDWDHKI97GN"

# Recursos computacionais
task_cpu    = 1024
task_memory = 2048
EOF 