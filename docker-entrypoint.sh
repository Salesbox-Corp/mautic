#!/bin/bash
set -e

# Debug básico
echo "=== Informações de Debug ==="
echo "Verificando diretório do EFS..."
ls -la /var/www/html/media || echo "Diretório media ainda não existe"
echo "==========================="

# Criar e configurar diretório do EFS
echo "Configurando diretório do EFS..."
mkdir -p /var/www/html/media/images
chown -R www-data:www-data /var/www/html/media
chmod -R 775 /var/www/html/media
echo "Diretório EFS configurado"

# Garantir diretórios básicos
mkdir -p /var/www/html/app/cache
mkdir -p /var/www/html/app/logs
chown -R www-data:www-data /var/www/html/app/cache /var/www/html/app/logs
chmod -R 775 /var/www/html/app/cache /var/www/html/app/logs

# Configurar Whitelabeler se necessário
if [ "$ENABLE_WHITELABEL" = "true" ]; then
    echo "=== Configurando Whitelabeler ==="
    
    # Criar config.json para o Whitelabeler
    mkdir -p /var/www/html/mautic-whitelabeler/assets
    cat > /var/www/html/mautic-whitelabeler/assets/config.json << EOF
{
    "company_name": "${MAUTIC_COMPANY_NAME:-Mautic}",
    "primary_color": "${MAUTIC_PRIMARY_COLOR:-#4e5e9e}",
    "secondary_color": "${MAUTIC_SECONDARY_COLOR:-#4e5e9e}",
    "link_color": "${MAUTIC_PRIMARY_COLOR:-#4e5e9e}",
    "login_logo_width": "300",
    "login_logo_margin": "50",
    "sidebar_logo_width": "200",
    "sidebar_logo_margin": "25"
}
EOF

    # Se tiver uma URL de logo customizada, fazer download
    if [ ! -z "$MAUTIC_CUSTOM_LOGO_URL" ]; then
        echo "Baixando logo customizado..."
        curl -L "$MAUTIC_CUSTOM_LOGO_URL" -o /var/www/html/media/images/custom_logo.png
        chmod 644 /var/www/html/media/images/custom_logo.png
    fi

    # Aplicar Whitelabeling
    cd /var/www/html
    php mautic-whitelabeler/cli.php --whitelabel
    echo "Whitelabeling aplicado com sucesso"
    echo "==================================="
fi

# Executar o comando original
exec "$@" 