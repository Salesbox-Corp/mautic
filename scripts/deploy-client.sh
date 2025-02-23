#!/bin/bash

CLIENT=$1
ENVIRONMENT=$2

if [ -z "$CLIENT" ] || [ -z "$ENVIRONMENT" ]; then
    echo "Usage: ./deploy-client.sh <client_name> <environment>"
    exit 1
fi

# Navegar para o diretório correto
cd terraform/environments/clients/$CLIENT/$ENVIRONMENT

# Inicializar e aplicar Terraform
terraform init \
    -backend-config="key=mautic/$CLIENT/$ENVIRONMENT/terraform.tfstate"

terraform apply \
    -var="client=$CLIENT" \
    -var="environment=$ENVIRONMENT" 