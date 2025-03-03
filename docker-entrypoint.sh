#!/bin/bash
set -e

# Debug básico
echo "=== Informações de Debug ==="
echo "Verificando montagem do EFS..."
df -h | grep /mautic || echo "EFS não está montado"
echo "Verificando diretório Mautic..."
ls -la /var/www/html || echo "Diretório Mautic não encontrado"
echo "==========================="

# Aguardar montagem do EFS (máximo 30 segundos)
echo "Aguardando montagem do EFS..."
timeout 30 sh -c 'while ! stat /mautic 2>/dev/null; do sleep 1; done' || \
{ echo "ERRO: EFS não montado após 30 segundos"; exit 1; }

# Criar diretórios de persistência no EFS, se não existirem
echo "Verificando diretórios no EFS..."
mkdir -p /mautic/media/images
mkdir -p /mautic/config
mkdir -p /mautic/cache
mkdir -p /mautic/logs
mkdir -p /mautic/app
mkdir -p /mautic/plugins
mkdir -p /mautic/translations

# Configurar symlinks para persistência apenas se não existirem
echo "Configurando symlinks..."
[ -L "/var/www/html/media" ] || ln -sf /mautic/media /var/www/html/media
[ -L "/var/www/html/app/config" ] || ln -sf /mautic/config /var/www/html/app/config
[ -L "/var/www/html/app/cache" ] || ln -sf /mautic/cache /var/www/html/app/cache
[ -L "/var/www/html/app/logs" ] || ln -sf /mautic/logs /var/www/html/app/logs
[ -L "/var/www/html/app" ] || ln -sf /mautic/app /var/www/html/app
[ -L "/var/www/html/plugins" ] || ln -sf /mautic/plugins /var/www/html/plugins
[ -L "/var/www/html/translations" ] || ln -sf /mautic/translations /var/www/html/translations

# Configurar permissões corretamente
echo "Configurando permissões..."
chown -R www-data:www-data /mautic/* || echo "Aviso: Alguns arquivos em /mautic não puderam ter o proprietário alterado"
chmod -R 775 /mautic/* || echo "Aviso: Algumas permissões em /mautic não puderam ser alteradas"

# Garantir que o arquivo .installed existe para evitar reinicialização do Mautic
echo "Verificando arquivo .installed..."
touch /mautic/config/.installed
chown www-data:www-data /mautic/config/.installed
chmod 664 /mautic/config/.installed

echo "Diretórios configurados e prontos."

# Garantir que o local.php seja carregado corretamente do EFS
if [ ! -f "/mautic/config/local.php" ]; then
    echo "Arquivo de configuração local.php não encontrado no EFS. Criando..."
    if [ -f "/var/www/html/app/config/local.php.dist" ]; then
        cp /var/www/html/app/config/local.php.dist /mautic/config/local.php
    else
        echo "Criando configuração padrão..."
        cat > /mautic/config/local.php << 'EOF'
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
    chown www-data:www-data /mautic/config/local.php
    chmod 664 /mautic/config/local.php
fi

# Garantir que o Mautic esteja apontando para o local.php correto
ln -sf /mautic/config/local.php /var/www/html/app/config/local.php

# Configurar Whitelabeler se necessário
if [ "$ENABLE_WHITELABEL" = "true" ]; then
    echo "=== Configurando Whitelabeler ==="

    # Instalar dependências necessárias
    echo "Instalando dependências..."
    apt-get update && apt-get install -y git curl npm

    # Clonar o Whitelabeler se ainda não estiver no EFS
    if [ ! -d "/mautic/mautic-whitelabeler" ]; then
        echo "Clonando Whitelabeler para o EFS..."
        git clone https://github.com/nickian/mautic-whitelabeler.git /mautic/mautic-whitelabeler
    fi

    # Criar symlink para o Whitelabeler dentro do Mautic
    ln -sf /mautic/mautic-whitelabeler /var/www/html/mautic-whitelabeler

    # Criar diretório de assets se não existir
    mkdir -p /var/www/html/assets

    # Criar config.json para o Whitelabeler
    cat > /var/www/html/assets/config.json << EOF
{
    "mautic_path": "/var/www/html",
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
        mkdir -p /var/www/html/assets/images
        curl -L "$MAUTIC_CUSTOM_LOGO_URL" -o /var/www/html/assets/images/custom_logo.png
        chmod 644 /var/www/html/assets/images/custom_logo.png
    fi

    # Instalar dependências do Mautic e Whitelabeler
    echo "Instalando dependências..."
    composer install --no-interaction --no-progress
    npm install

    # Gerar assets do Mautic
    echo "Gerando assets..."
    php bin/console mautic:assets:generate

    # Aplicar Whitelabeling
    echo "Aplicando Whitelabeling..."
    sudo -u www-data php cli.php --whitelabel

    # Limpar cache
    echo "Limpando cache..."
    php bin/console cache:clear

    echo "Processo de Whitelabeling concluído"
fi

# Executar o comando original do container
exec "$@"