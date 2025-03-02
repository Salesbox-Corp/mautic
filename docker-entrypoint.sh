#!/bin/bash
set -e

# Debug básico
echo "=== Informações de Debug ==="
echo "Verificando diretório do EFS..."
ls -la /mautic || echo "Diretório /mautic ainda não existe"
echo "==========================="

# Criar e configurar diretório base do EFS
echo "Configurando diretório do EFS..."
mkdir -p /mautic
chown www-data:www-data /mautic
chmod 775 /mautic

# Criar estrutura de diretórios no EFS
mkdir -p /mautic/media/images
mkdir -p /mautic/config
mkdir -p /mautic/cache
mkdir -p /mautic/logs

# Configurar permissões
chown -R www-data:www-data /mautic/*
chmod -R 775 /mautic/*

# Criar links simbólicos para os diretórios do Mautic
ln -sfn /mautic/media /var/www/html/media
ln -sfn /mautic/config /var/www/html/app/config
ln -sfn /mautic/cache /var/www/html/app/cache
ln -sfn /mautic/logs /var/www/html/app/logs

# Garantir que o arquivo .installed existe
touch /mautic/config/.installed
chown www-data:www-data /mautic/config/.installed
chmod 664 /mautic/config/.installed

echo "Diretórios EFS configurados"

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
        curl -L "$MAUTIC_CUSTOM_LOGO_URL" -o /mautic/media/images/custom_logo.png
        chmod 644 /mautic/media/images/custom_logo.png
    fi

    # Aplicar Whitelabeling
    cd /var/www/html
    php mautic-whitelabeler/cli.php --whitelabel
    echo "Whitelabeling aplicado com sucesso"
    echo "==================================="
fi

# Verificar e copiar arquivos de configuração se necessário
if [ ! -f "/mautic/config/local.php" ]; then
    echo "Criando arquivo de configuração local..."
    cp /var/www/html/app/config/local.php.dist /mautic/config/local.php
    chown www-data:www-data /mautic/config/local.php
    chmod 664 /mautic/config/local.php
fi

# Executar o comando original
exec "$@" 