#!/bin/bash
set -e

# Verificar argumentos
if [ "$#" -lt 2 ]; then
    echo "Uso: $0 <client_id> <client_name> [logo_url]"
    echo "Exemplo: $0 exemplo-cliente \"Exemplo Cliente\" https://exemplo.com/logo.png"
    exit 1
fi

CLIENT_ID="$1"
CLIENT_NAME="$2"
LOGO_URL="${3:-}"

# Criar diretório clients se não existir
mkdir -p clients

# Criar config.json se não existir
if [ ! -f clients/config.json ]; then
    echo '{
    "clients": {}
}' > clients/config.json
fi

# Adicionar novo cliente ao config.json
if [ -z "$LOGO_URL" ]; then
    # Sem logo_url
    jq --arg id "$CLIENT_ID" --arg name "$CLIENT_NAME" '.clients[$id] = {
        "name": $name,
        "environments": {
            "demo": {},
            "staging": {},
            "prd": {}
        }
    }' clients/config.json > clients/config.json.tmp
else
    # Com logo_url
    jq --arg id "$CLIENT_ID" --arg name "$CLIENT_NAME" --arg logo "$LOGO_URL" '.clients[$id] = {
        "name": $name,
        "logo_url": $logo,
        "environments": {
            "demo": {},
            "staging": {},
            "prd": {}
        }
    }' clients/config.json > clients/config.json.tmp
fi

mv clients/config.json.tmp clients/config.json

echo "Cliente '$CLIENT_NAME' ($CLIENT_ID) adicionado com sucesso!" 