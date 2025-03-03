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

# Verificar se media é um symlink e criar estrutura apropriada
if [ -L "/var/www/html/media" ]; then
    echo "Media é um symlink, verificando destino..."
    MEDIA_TARGET=$(readlink "/var/www/html/media")
    echo "Media aponta para: $MEDIA_TARGET"
    
    # Criar diretórios no destino do symlink
    mkdir -p "${MEDIA_TARGET}/images" 2>/dev/null || echo "Diretório ${MEDIA_TARGET}/images já existe"
else
    echo "Media não é um symlink, criando diretório padrão..."
    mkdir -p /var/www/html/media/images 2>/dev/null || echo "Diretório media/images já existe"
fi

# Criar outros diretórios necessários
mkdir -p /var/www/html/app/config 2>/dev/null || echo "Diretório app/config já existe"
mkdir -p /var/www/html/app/cache 2>/dev/null || echo "Diretório app/cache já existe"
mkdir -p /var/www/html/app/logs 2>/dev/null || echo "Diretório app/logs já existe"

# Configurar permissões (ignorando erros)
echo "Configurando permissões..."
if [ -L "/var/www/html/media" ]; then
    MEDIA_TARGET=$(readlink "/var/www/html/media")
    echo "Configurando permissões do diretório media: $MEDIA_TARGET"
    chown -R www-data:www-data "$MEDIA_TARGET" 2>/dev/null || echo "Aviso: Alguns arquivos em $MEDIA_TARGET não puderam ter o proprietário alterado"
    chmod -R 775 "$MEDIA_TARGET" 2>/dev/null || echo "Aviso: Algumas permissões em $MEDIA_TARGET não puderam ser alteradas"
fi

chown -R www-data:www-data /var/www/html 2>/dev/null || echo "Aviso: Alguns arquivos não puderam ter o proprietário alterado"
chmod -R 775 /var/www/html 2>/dev/null || echo "Aviso: Algumas permissões não puderam ser alteradas"

# Garantir que o arquivo .installed existe
echo "Verificando arquivo .installed..."
touch /var/www/html/app/config/.installed 2>/dev/null || echo "Aviso: Não foi possível criar/atualizar .installed"
chown www-data:www-data /var/www/html/app/config/.installed 2>/dev/null || echo "Aviso: Não foi possível alterar proprietário do .installed"
chmod 664 /var/www/html/app/config/.installed 2>/dev/null || echo "Aviso: Não foi possível alterar permissões do .installed"

echo "Diretórios configurados"

# Verificar e copiar arquivos de configuração se necessário
if [ ! -f "/var/www/html/app/config/local.php" ]; then
    echo "Criando arquivo de configuração local..."
    if [ -f "/var/www/html/app/config/local.php.dist" ]; then
        cp /var/www/html/app/config/local.php.dist /var/www/html/app/config/local.php 2>/dev/null || echo "Aviso: Não foi possível copiar local.php.dist"
    else
        echo "Criando configuração padrão..."
        cat > /var/www/html/app/config/local.php << 'EOF' 2>/dev/null || echo "Aviso: Não foi possível criar local.php"
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
    chown www-data:www-data /var/www/html/app/config/local.php 2>/dev/null || echo "Aviso: Não foi possível alterar proprietário do local.php"
    chmod 664 /var/www/html/app/config/local.php 2>/dev/null || echo "Aviso: Não foi possível alterar permissões do local.php"
fi

# Configurar Whitelabeler se necessário
if [ "$ENABLE_WHITELABEL" = "true" ]; then
    echo "=== Configurando Whitelabeler ==="
    
    # Clonar o Whitelabeler se não existir
    if [ ! -d "/var/www/html/mautic-whitelabeler" ]; then
        echo "Clonando Whitelabeler..."
        git clone https://github.com/mautic/mautic-whitelabeler.git /var/www/html/mautic-whitelabeler 2>/dev/null || echo "Aviso: Não foi possível clonar Whitelabeler"
        chown -R www-data:www-data /var/www/html/mautic-whitelabeler 2>/dev/null || echo "Aviso: Não foi possível alterar proprietário do Whitelabeler"
        chmod -R 775 /var/www/html/mautic-whitelabeler 2>/dev/null || echo "Aviso: Não foi possível alterar permissões do Whitelabeler"
    fi
    
    # Criar config.json para o Whitelabeler
    mkdir -p /var/www/html/mautic-whitelabeler/assets 2>/dev/null || echo "Diretório assets já existe"
    cat > /var/www/html/mautic-whitelabeler/assets/config.json << EOF 2>/dev/null || echo "Aviso: Não foi possível criar config.json"
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
        curl -L "$MAUTIC_CUSTOM_LOGO_URL" -o /var/www/html/media/images/custom_logo.png 2>/dev/null || echo "Aviso: Não foi possível baixar logo customizado"
        chmod 644 /var/www/html/media/images/custom_logo.png 2>/dev/null || echo "Aviso: Não foi possível alterar permissões do logo"
    fi

    # Aplicar Whitelabeling
    cd /var/www/html
    php mautic-whitelabeler/cli.php --whitelabel --mautic-path=/var/www/html || echo "Aviso: Não foi possível aplicar Whitelabeling"
    echo "Processo de Whitelabeling concluído"
fi

# Executar o comando original
exec "$@" 