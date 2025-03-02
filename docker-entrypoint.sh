#!/bin/bash
set -e

# Debug básico
echo "=== Informações de Debug ==="
echo "Verificando montagem do EFS..."
df -h | grep media || echo "EFS não está montado"
echo "Verificando diretório media..."
ls -la /var/www/html/media || echo "Diretório media ainda não existe"
echo "Verificando diretório Mautic..."
ls -la /var/www/html || echo "Diretório Mautic não encontrado"
echo "==========================="

# Aguardar montagem do EFS (máximo 30 segundos)
echo "Aguardando montagem do EFS..."
counter=0
while [ ! -d "/var/www/html/media" ] && [ $counter -lt 30 ]; do
    sleep 1
    counter=$((counter+1))
    echo "Tentativa $counter de 30..."
done

if [ ! -d "/var/www/html/media" ]; then
    echo "ERRO: EFS não montado após 30 segundos"
    exit 1
fi

# Criar estrutura de diretórios no EFS
echo "Configurando diretórios persistentes..."
mkdir -p /var/www/html/media/images
mkdir -p /var/www/html/app/config
mkdir -p /var/www/html/app/cache
mkdir -p /var/www/html/app/logs

# Configurar permissões
chown -R www-data:www-data /var/www/html/media
chmod -R 775 /var/www/html/media
chown -R www-data:www-data /var/www/html/app/config
chmod -R 775 /var/www/html/app/config
chown -R www-data:www-data /var/www/html/app/cache
chmod -R 775 /var/www/html/app/cache
chown -R www-data:www-data /var/www/html/app/logs
chmod -R 775 /var/www/html/app/logs

# Garantir que o arquivo .installed existe
touch /var/www/html/app/config/.installed
chown www-data:www-data /var/www/html/app/config/.installed
chmod 664 /var/www/html/app/config/.installed

echo "Diretórios configurados"

# Verificar e copiar arquivos de configuração se necessário
if [ ! -f "/var/www/html/app/config/local.php" ]; then
    echo "Criando arquivo de configuração local..."
    if [ -f "/var/www/html/app/config/local.php.dist" ]; then
        cp /var/www/html/app/config/local.php.dist /var/www/html/app/config/local.php
    else
        echo "Criando configuração padrão..."
        cat > /var/www/html/app/config/local.php << 'EOF'
<?php
$parameters = array(
    'db_driver' => 'pdo_mysql',
    'db_host' => getenv('MAUTIC_DB_HOST'),
    'db_port' => getenv('MAUTIC_DB_PORT'),
    'db_name' => getenv('MAUTIC_DB_NAME'),
    'db_user' => getenv('MAUTIC_DB_USER'),
    'db_password' => getenv('MAUTIC_DB_PASSWORD'),
    'db_table_prefix' => getenv('MAUTIC_TABLE_PREFIX'),
    'db_backup_tables' => 1,
    'db_backup_prefix' => 'bak_',
    'admin_email' => getenv('MAUTIC_ADMIN_EMAIL'),
    'admin_password' => getenv('MAUTIC_ADMIN_PASSWORD'),
    'site_url' => getenv('MAUTIC_URL')
);
EOF
    fi
    chown www-data:www-data /var/www/html/app/config/local.php
    chmod 664 /var/www/html/app/config/local.php
fi

# Configurar Whitelabeler se necessário
if [ "$ENABLE_WHITELABEL" = "true" ]; then
    echo "=== Configurando Whitelabeler ==="
    
    # Clonar o Whitelabeler se não existir
    if [ ! -d "/var/www/html/mautic-whitelabeler" ]; then
        echo "Clonando Whitelabeler..."
        git clone https://github.com/mautic/mautic-whitelabeler.git /var/www/html/mautic-whitelabeler
        chown -R www-data:www-data /var/www/html/mautic-whitelabeler
        chmod -R 775 /var/www/html/mautic-whitelabeler
    fi
    
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
fi

# Executar o comando original
exec "$@" 