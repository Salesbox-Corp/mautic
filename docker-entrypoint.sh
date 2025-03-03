#!/bin/bash
set -e

# Debug inicial
echo "=== Informações de Debug ==="
echo "Verificando montagem do EFS..."
df -h | grep /mautic && echo "✅ EFS está montado." || echo "⚠️ EFS NÃO ESTÁ MONTADO!"
echo "Verificando diretório Mautic..."
ls -la /var/www/html || echo "⚠️ Diretório Mautic não encontrado!"
echo "==========================="

# **Parar o Apache temporariamente para evitar locks**
echo "⏳ Parando Apache temporariamente para evitar locks..."
service apache2 stop || echo "⚠️ Apache não estava rodando."

# Aguardar montagem do EFS (máximo 30 segundos)
echo "Aguardando montagem do EFS..."
for i in {1..30}; do
    if df -h | grep -q /mautic; then
        echo "✅ EFS detectado e montado!"
        break
    fi
    echo "⏳ Tentativa $i/30 - Aguardando EFS..."
    sleep 1
done

# Se ainda não estiver montado, sair com erro
if ! df -h | grep -q /mautic; then
    echo "❌ ERRO: O EFS não foi montado corretamente!"
    exit 1
fi

# Se o Mautic ainda não foi copiado para o EFS, fazer a cópia inicial
if [ ! -d "/mautic/html" ]; then
    echo "📂 Copiando Mautic para o EFS pela primeira vez..."
    mkdir -p /mautic/html
    cp -R /var/www/html/* /mautic/html/
    chown -R www-data:www-data /mautic/html
    chmod -R 775 /mautic/html
else
    echo "✅ Mautic já está salvo no EFS. Pulando cópia."
fi

# **Evitar remoção de diretórios que já são volumes montados no EFS**
echo "🔍 Verificando volumes para evitar conflitos..."
for dir in "/var/www/html/app/logs" "/var/www/html/app/cache"; do
    if mount | grep -q "$dir"; then
        echo "⚠️ $dir já é um volume montado. Pulando remoção."
    else
        echo "🗑️ Tentando remover $dir para recriação do symlink..."
        rm -rf "$dir" 2>/dev/null || echo "⚠️ Falha ao remover $dir, ignorando."
    fi
done

# **Corrigir permissões de diretórios antes de criar os symlinks**
echo "🔧 Ajustando permissões antes de criar symlinks..."
chown -R www-data:www-data /mautic/*
chmod -R 775 /mautic/*

# **Criar symlink de /var/www/html para o EFS se ainda não existir**
if [ ! -L "/var/www/html" ] && [ ! -d "/var/www/html" ]; then
    echo "🔗 Criando symlink de /var/www/html para o EFS..."
    ln -s /mautic/html /var/www/html
fi

# Criar diretórios essenciais no EFS, se não existirem
echo "📂 Criando diretórios persistentes no EFS..."
mkdir -p /mautic/media/images
mkdir -p /mautic/config
mkdir -p /mautic/cache
mkdir -p /mautic/logs
mkdir -p /mautic/plugins
mkdir -p /mautic/translations

# Criar symlinks para persistência de diretórios internos
echo "🔗 Criando symlinks para diretórios essenciais..."
[ -L "/var/www/html/media" ] || ln -sf /mautic/media /var/www/html/media
[ -L "/var/www/html/app/config" ] || ln -sf /mautic/config /var/www/html/app/config
[ -L "/var/www/html/app/cache" ] || ln -sf /mautic/cache /var/www/html/app/cache
[ -L "/var/www/html/app/logs" ] || ln -sf /mautic/logs /var/www/html/app/logs
[ -L "/var/www/html/plugins" ] || ln -sf /mautic/plugins /var/www/html/plugins
[ -L "/var/www/html/translations" ] || ln -sf /mautic/translations /var/www/html/translations

# Garantir que o arquivo .installed existe para evitar reinstalação
echo "🛠️ Verificando arquivo .installed..."
touch /mautic/config/.installed
chown www-data:www-data /mautic/config/.installed
chmod 664 /mautic/config/.installed

# Garantir que o local.php seja carregado corretamente do EFS
if [ ! -f "/mautic/config/local.php" ]; then
    echo "⚠️ local.php não encontrado no EFS. Criando..."
    if [ -f "/var/www/html/app/config/local.php.dist" ]; then
        cp /var/www/html/app/config/local.php.dist /mautic/config/local.php
    else
        echo "📜 Criando configuração padrão..."
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

echo "✅ Configuração concluída. Reiniciando Apache..."
service apache2 start

# Executar o comando original do container
exec "$@"
