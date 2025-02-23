#!/bin/bash

function create_release() {
    VERSION=$1
    git checkout main
    git checkout -b releases/v${VERSION}
    # Atualizar versão nos arquivos necessários
    git commit -am "Release version ${VERSION}"
    git tag v${VERSION}
    git push origin releases/v${VERSION} --tags
}

function deploy_to_client() {
    CLIENT=$1
    ENVIRONMENT=$2
    VERSION=$3

    # Criar/atualizar branch do cliente
    git checkout releases/v${VERSION}
    git checkout -B clients/${CLIENT}/${ENVIRONMENT}
    
    # Aplicar configurações específicas do cliente
    cp -r config/clients/${CLIENT}/* .
    
    git commit -am "Deploy ${VERSION} to ${CLIENT}/${ENVIRONMENT}"
    git push origin clients/${CLIENT}/${ENVIRONMENT}
} 