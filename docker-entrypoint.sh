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

# Criar diretórios essenciais no EFS, se não existirem
echo "📂 Criando diretórios persistentes no EFS..."
mkdir -p /mautic/media/images /mautic/config /mautic/cache /mautic/logs /mautic/plugins /mautic/translations

# **Evitar loops de symlinks**
echo "🔗 Verificando e criando symlinks para persistência..."

symlink_safe() {
    local target=$1
    local link=$2

    # Se já existir como diretório real, não criar symlink
    if [ -d "$link" ] && [ ! -L "$link" ]; then
        echo "✅ $link já é um diretório real, pulando symlink."
        return
    fi

    # Se já existir como symlink quebrado, removê-lo
    if [ -L "$link" ] && [ ! -e "$link" ]; then
        echo "🗑️ Removendo symlink quebrado: $link"
        rm -f "$link"
    fi

    # Criar symlink seguro
    echo "🔗 Criando symlink: $link -> $target"
    ln -sf "$target" "$link"
}

symlink_safe "/mautic/media" "/var/www/html/media"
symlink_safe "/mautic/config" "/var/www/html/app/config"
symlink_safe "/mautic/cache" "/var/www/html/app/cache"
symlink_safe "/mautic/logs" "/var/www/html/app/logs"
symlink_safe "/mautic/plugins" "/var/www/html/plugins"
symlink_safe "/mautic/translations" "/var/www/html/translations"

# **Corrigir permissões sem afetar symlinks**
echo "🔧 Ajustando permissões antes de iniciar..."
find /mautic -type d -exec chmod 775 {} +
find /mautic -type f -exec chmod 664 {} +
chown -R www-data:www-data /mautic

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
