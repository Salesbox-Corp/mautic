#!/bin/bash
set -e

# Debug: Mostrar variáveis de ambiente e resolver DNS
echo "=== Informações de Debug ==="
echo "DB_HOST: $MAUTIC_DB_HOST"
echo "DB_PORT: $MAUTIC_DB_PORT"
echo "DB_NAME: $MAUTIC_DB_NAME"
echo "DB_USER: $MAUTIC_DB_USER"
echo "SITE_URL: $MAUTIC_SITE_URL"
echo "Resolvendo DNS do host do banco:"
getent hosts "$MAUTIC_DB_HOST" || echo "Não foi possível resolver o host"
echo "==========================="

# Garantir que o SITE_URL tenha um valor padrão
SITE_URL="${MAUTIC_SITE_URL:-http://localhost}"
echo "Site URL que será usado: $SITE_URL"

# Criar diretórios no EFS
echo "Criando diretórios no EFS..."
mkdir -p /var/www/html/media/images
chown -R www-data:www-data /var/www/html/media
chmod -R 775 /var/www/html/media

# Copiar logo para o EFS se não existir
if [ ! -f /var/www/html/media/images/mautic_logo_db.png ]; then
    echo "Copiando logo para o EFS..."
    cp /var/www/html/app/assets/images/mautic_logo.png /var/www/html/media/images/mautic_logo_db.png
    chown www-data:www-data /var/www/html/media/images/mautic_logo_db.png
    chmod 644 /var/www/html/media/images/mautic_logo_db.png
fi

# Garantir que os diretórios existam com permissões corretas
mkdir -p /var/www/html/app/config
mkdir -p /var/www/html/app/cache
mkdir -p /var/www/html/app/logs
mkdir -p /var/www/html/app/spool

# Ajustar permissões (775 permite escrita pelo grupo www-data)
chown -R www-data:www-data /var/www/html
find /var/www/html -type d -exec chmod 775 {} \;
find /var/www/html -type f -exec chmod 664 {} \;

# Remover arquivos de configuração existentes
rm -f /var/www/html/app/config/local.php
rm -f /var/www/html/app/config/parameters_local.php

# Criar arquivo local.php com valores diretos
echo "Criando arquivo local.php..."
cat > /var/www/html/app/config/local.php << EOF
<?php
\$site_url = getenv('MAUTIC_SITE_URL');
if (empty(\$site_url)) {
    \$site_url = 'http://localhost';
}

return [
    'db_driver' => 'pdo_mysql',
    'db_host' => '${MAUTIC_DB_HOST}',
    'db_port' => ${MAUTIC_DB_PORT:-3306},
    'db_name' => '${MAUTIC_DB_NAME}',
    'db_user' => '${MAUTIC_DB_USER}',
    'db_password' => '${MAUTIC_DB_PASSWORD}',
    'mailer_from_name' => '${MAUTIC_ADMIN_FROM_NAME}',
    'mailer_from_email' => '${MAUTIC_ADMIN_FROM_EMAIL}',
    'installed' => true,
    'is_installed' => true,
    'db_installed' => true,
    'site_url' => \$site_url,
];
EOF

# Criar banco de dados se for primeira instalação
if [ "$IS_FIRST_INSTALL" = "true" ]; then
  echo "Criando banco de dados..."
  /usr/local/bin/manage-database.sh create_client_database "$CLIENT" "$ENVIRONMENT" "$AWS_REGION"
fi

# Copiar local.php para parameters_local.php
cp /var/www/html/app/config/local.php /var/www/html/app/config/parameters_local.php

# Ajustar permissões dos arquivos de configuração
chown www-data:www-data /var/www/html/app/config/local.php /var/www/html/app/config/parameters_local.php
chmod 644 /var/www/html/app/config/local.php /var/www/html/app/config/parameters_local.php

# Criar arquivo .installed
touch /var/www/html/app/config/.installed
chown www-data:www-data /var/www/html/app/config/.installed
chmod 644 /var/www/html/app/config/.installed

# Limpar cache e rodar migrations
echo "=== Executando comandos do Mautic ==="
cd /var/www/html

# Limpar cache de forma mais agressiva
rm -rf /var/www/html/app/cache/*
rm -rf /var/www/html/app/logs/*
php bin/console cache:clear --no-warmup --no-interaction
php bin/console doctrine:migrations:migrate --no-interaction
php bin/console doctrine:schema:update --force --no-interaction
php bin/console mautic:install:data --force --no-interaction

# Recriar cache
php bin/console cache:warmup --no-interaction

# Verificar status do banco
php bin/console doctrine:schema:validate

echo "==================================="

# Verificar conteúdo final
echo "=== Verificando configuração final ==="
echo "Conteúdo do local.php:"
cat /var/www/html/app/config/local.php | grep -v password
echo "Permissões:"
ls -l /var/www/html/app/config/local.php /var/www/html/app/config/parameters_local.php
echo "==================================="

# Configurar Whitelabeler se necessário
if [ -n "$ENABLE_WHITELABEL" ] && [ "$ENABLE_WHITELABEL" = "true" ]; then
    echo "=== Configurando Whitelabeler ==="
    if [ -f /var/www/html/mautic-whitelabeler/assets/config.json ]; then
        cd /var/www/html
        php mautic-whitelabeler/cli.php --whitelabel
        echo "Whitelabeling aplicado com sucesso"
    else
        echo "Arquivo de configuração do Whitelabeler não encontrado"
    fi
    echo "==================================="
fi

# Executar o comando original
exec "$@" 