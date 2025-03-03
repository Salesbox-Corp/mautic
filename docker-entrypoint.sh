#!/bin/bash
set -e

# Debug básico
echo "=== Informações de Debug ==="
echo "Verificando montagem do EFS..."
df -h | grep html || echo "EFS não está montado"
echo "Verificando diretório Mautic..."
ls -la /var/www/html || echo "Diretório Mautic não encontrado"
echo "==========================="

# Aguardar montagem do EFS (máximo 30 segundos)
echo "Aguardando montagem do EFS..."
counter=0
while [ ! -d "/var/www/html" ] && [ $counter -lt 30 ]; do
    sleep 1
    counter=$((counter+1))
    echo "Tentativa $counter de 30..."
done

if [ ! -d "/var/www/html" ]; then
    echo "ERRO: EFS não montado após 30 segundos"
    exit 1
fi

# Verificar e criar diretórios necessários
echo "Configurando diretórios..."

# Verificar se os diretórios de persistência existem no EFS
echo "Verificando diretórios no EFS..."
mkdir -p /mautic/media/images 2>/dev/null || echo "Diretório media/images já existe"
mkdir -p /mautic/config 2>/dev/null || echo "Diretório config já existe"
mkdir -p /mautic/cache 2>/dev/null || echo "Diretório cache já existe"
mkdir -p /mautic/logs 2>/dev/null || echo "Diretório logs já existe"

# Configurar symlinks para persistência
echo "Configurando symlinks..."
# Media já está configurado como symlink pelo container
[ -L "/var/www/html/media" ] || ln -sf /mautic/media /var/www/html/media
[ -L "/var/www/html/app/config" ] || ln -sf /mautic/config /var/www/html/app/config
[ -L "/var/www/html/app/cache" ] || ln -sf /mautic/cache /var/www/html/app/cache
[ -L "/var/www/html/app/logs" ] || ln -sf /mautic/logs /var/www/html/app/logs

# Configurar permissões
echo "Configurando permissões..."
chown -R www-data:www-data /mautic/* 2>/dev/null || echo "Aviso: Alguns arquivos em /mautic não puderam ter o proprietário alterado"
chmod -R 775 /mautic/* 2>/dev/null || echo "Aviso: Algumas permissões em /mautic não puderam ser alteradas"

# Garantir que o arquivo .installed existe
echo "Verificando arquivo .installed..."
touch /mautic/config/.installed 2>/dev/null || echo "Aviso: Não foi possível criar/atualizar .installed"
chown www-data:www-data /mautic/config/.installed 2>/dev/null || echo "Aviso: Não foi possível alterar proprietário do .installed"
chmod 664 /mautic/config/.installed 2>/dev/null || echo "Aviso: Não foi possível alterar permissões do .installed"

echo "Diretórios configurados"

# Verificar e copiar arquivos de configuração se necessário
if [ ! -f "/mautic/config/local.php" ]; then
    echo "Criando arquivo de configuração local..."
    if [ -f "/var/www/html/app/config/local.php.dist" ]; then
        cp /var/www/html/app/config/local.php.dist /mautic/config/local.php 2>/dev/null || echo "Aviso: Não foi possível copiar local.php.dist"
    else
        echo "Criando configuração padrão..."
        cat > /mautic/config/local.php << 'EOF' 2>/dev/null || echo "Aviso: Não foi possível criar local.php"
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
    chown www-data:www-data /mautic/config/local.php 2>/dev/null || echo "Aviso: Não foi possível alterar proprietário do local.php"
    chmod 664 /mautic/config/local.php 2>/dev/null || echo "Aviso: Não foi possível alterar permissões do local.php"
fi

# Executar o comando original
exec "$@" 