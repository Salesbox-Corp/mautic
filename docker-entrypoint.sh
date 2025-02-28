#!/bin/bash
set -e

# Debug: Mostrar variáveis de ambiente e resolver DNS
echo "=== Informações de Debug ==="
echo "DB_HOST: $MAUTIC_DB_HOST"
echo "DB_PORT: $MAUTIC_DB_PORT"
echo "DB_NAME: $MAUTIC_DB_NAME"
echo "DB_USER: $MAUTIC_DB_USER"
echo "Resolvendo DNS do host do banco:"
getent hosts "$MAUTIC_DB_HOST" || echo "Não foi possível resolver o host"
echo "==========================="

# Garantir que os diretórios existam com permissões corretas
mkdir -p /var/www/html/app/config
mkdir -p /var/www/html/media/images
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
\$parameters = array(
    'db_driver' => 'pdo_mysql',
    'db_host' => '${MAUTIC_DB_HOST}',
    'db_port' => ${MAUTIC_DB_PORT:-3306},
    'db_name' => '${MAUTIC_DB_NAME}',
    'db_user' => '${MAUTIC_DB_USER}',
    'db_password' => '${MAUTIC_DB_PASSWORD}',
    'db_table_prefix' => null,
    'db_backup_tables' => false,
    'db_backup_prefix' => 'bak_',
    'admin_email' => '${MAUTIC_ADMIN_EMAIL}',
    'admin_password' => '${MAUTIC_ADMIN_PASSWORD}',
    'admin_firstname' => '${MAUTIC_ADMIN_FIRSTNAME}',
    'admin_lastname' => '${MAUTIC_ADMIN_LASTNAME}',
    'mailer_from_name' => '${MAUTIC_MAILER_FROM_NAME}',
    'mailer_from_email' => '${MAUTIC_MAILER_FROM_EMAIL}',
    'mailer_transport' => '${MAUTIC_MAILER_TRANSPORT}',
    'mailer_host' => '${MAUTIC_MAILER_HOST}',
    'mailer_port' => '${MAUTIC_MAILER_PORT}',
    'mailer_user' => '${MAUTIC_MAILER_USER}',
    'mailer_password' => '${MAUTIC_MAILER_PASSWORD}',
    'mailer_encryption' => '${MAUTIC_MAILER_ENCRYPTION}',
    'mailer_auth_mode' => '${MAUTIC_MAILER_AUTH_MODE}',
    'mailer_spool_type' => 'file',
    'mailer_spool_path' => '%kernel.root_dir%/spool',
    'secret_key' => '${MAUTIC_SECRET_KEY:-def00000fc1e34ca0f47d0c99c19768c551b451a956c9f83d308cca6b09518bb5204d51ff5fca14f}',
    'site_url' => '${MAUTIC_URL}',
    'image_path' => 'media/images',
    'tmp_path' => '/tmp',
    'theme' => '${MAUTIC_THEME:-blank}',
    'locale' => '${MAUTIC_LOCALE:-pt_BR}',
    'timezone' => '${MAUTIC_TIMEZONE:-America/Sao_Paulo}',
    'installed' => true,
    'is_installed' => true,
    'db_installed' => true,
    'install_source' => 'docker'
);
EOF

# Copiar local.php para parameters_local.php
cp /var/www/html/app/config/local.php /var/www/html/app/config/parameters_local.php

# Ajustar permissões dos arquivos de configuração
chown www-data:www-data /var/www/html/app/config/local.php /var/www/html/app/config/parameters_local.php
chmod 644 /var/www/html/app/config/local.php /var/www/html/app/config/parameters_local.php

# Criar arquivo .installed
touch /var/www/html/app/config/.installed
chown www-data:www-data /var/www/html/app/config/.installed
chmod 644 /var/www/html/app/config/.installed

# Limpar cache
rm -rf /var/www/html/app/cache/*

# Verificar conteúdo final
echo "=== Verificando configuração final ==="
echo "Conteúdo do local.php:"
cat /var/www/html/app/config/local.php | grep -v password
echo "Permissões:"
ls -l /var/www/html/app/config/local.php /var/www/html/app/config/parameters_local.php
echo "==================================="

# Executar o comando original
exec "$@" 