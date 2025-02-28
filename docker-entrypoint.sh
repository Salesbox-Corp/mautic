#!/bin/bash
set -e

# Criar arquivo de healthcheck
echo "Criando arquivo de healthcheck..."
cat > /var/www/html/health.php << EOF
<?php
header('Content-Type: application/json');
echo json_encode(['status' => 'healthy', 'timestamp' => time()]);
EOF

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

# Testar conexão com o banco como www-data
echo "Testando conexão com o banco de dados como www-data..."
su -s /bin/bash www-data -c "mysql -h\"$MAUTIC_DB_HOST\" -P\"$MAUTIC_DB_PORT\" -u\"$MAUTIC_DB_USER\" -p\"$MAUTIC_DB_PASSWORD\" -e \"SELECT 1\" 2>&1" || echo "Falha na conexão como www-data"

# Criar arquivo local.php com configurações básicas se não existir
if [ ! -f /var/www/html/app/config/local.php ]; then
    echo "Criando arquivo local.php..."
    # Criar arquivo como usuário www-data
    su -s /bin/bash -c "cat > /var/www/html/app/config/local.php" www-data << EOF
<?php
\$parameters = [
    // Configurações do Banco de Dados
    'db_driver' => 'pdo_mysql',
    'db_host' => '$MAUTIC_DB_HOST',  // Usando valor direto ao invés de getenv
    'db_port' => '$MAUTIC_DB_PORT',
    'db_name' => '$MAUTIC_DB_NAME',
    'db_user' => '$MAUTIC_DB_USER',
    'db_password' => '$MAUTIC_DB_PASSWORD',
    'db_table_prefix' => '$MAUTIC_TABLE_PREFIX',
    'db_backup_prefix' => 'bak_',
    'db_backup_tables' => true,

    // Configurações do Site
    'site_url' => getenv('MAUTIC_URL'),
    
    // Bypass da Instalação
    'db_installed' => true,
    'installed' => true,
    'install_source' => getenv('MAUTIC_INSTALL_SOURCE'),
    
    // Configurações de Email
    'mailer_from_name' => 'Mautic Admin',
    'mailer_from_email' => getenv('MAUTIC_ADMIN_EMAIL'),
    'mailer_transport' => 'smtp',
    'mailer_host' => null,
    'mailer_port' => null,
    'mailer_user' => null,
    'mailer_password' => null,
    'mailer_encryption' => null,
    'mailer_auth_mode' => null,
    
    // Configurações do Sistema
    'secret_key' => '$(openssl rand -hex 32)',
    'admin_email' => getenv('MAUTIC_ADMIN_EMAIL'),
    'admin_password' => getenv('MAUTIC_ADMIN_PASSWORD'),
    
    // Configurações de Cache
    'cache_path' => '/var/www/html/app/cache',
    'log_path' => '/var/www/html/app/logs',
    'tmp_path' => '/var/www/html/app/cache',
    'image_path' => 'media/images',
    
    // Configurações Regionais
    'locale' => 'pt_BR',
    'timezone' => 'America/Sao_Paulo',
    
    // Configurações de Segurança
    'rememberme_key' => '$(openssl rand -hex 32)',
    'rememberme_lifetime' => 31536000,
    'rememberme_path' => '/',
    'rememberme_domain' => '',

    // Outras Configurações
    'theme' => 'blank'
];
EOF

    echo "Arquivo local.php criado com sucesso!"
    echo "Conteúdo do arquivo local.php (sem senhas):"
    grep -v password /var/www/html/app/config/local.php
fi

# Configurar logo personalizado se a URL for fornecida
if [ ! -z "$MAUTIC_CUSTOM_LOGO_URL" ]; then
    echo "Configurando logo personalizado..."
    
    # Baixar a imagem como www-data
    su -s /bin/bash -c "curl -s -L '$MAUTIC_CUSTOM_LOGO_URL' -o /var/www/html/media/images/custom_logo.png" www-data
    
    # Verificar se o download foi bem sucedido
    if [ $? -eq 0 ]; then
        # Atualizar configuração do Mautic para usar o logo personalizado
        su -s /bin/bash -c "sed -i \"/\\\$parameters = \[/a\    'logo_image' => 'images/custom_logo.png',\" /var/www/html/app/config/local.php" www-data
        echo "Logo personalizado configurado com sucesso"
    else
        echo "Erro ao baixar logo personalizado. Usando logo padrão."
    fi
fi

# Garantir que o Apache possa escrever nos diretórios necessários
chown -R www-data:www-data /var/www/html/app/cache
chown -R www-data:www-data /var/www/html/app/logs
chown -R www-data:www-data /var/www/html/app/config
chown -R www-data:www-data /var/www/html/app/spool
chown -R www-data:www-data /var/www/html/media

# Limpar cache do Mautic
rm -rf /var/www/html/app/cache/*

# Instalar mysql-client para debug
apt-get update && apt-get install -y default-mysql-client

echo "Iniciando Apache..."
# Iniciar Apache em foreground
apache2-foreground 