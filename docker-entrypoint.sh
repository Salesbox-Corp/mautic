#!/bin/bash
set -e

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

# Criar arquivo local.php com configurações básicas se não existir
if [ ! -f /var/www/html/app/config/local.php ]; then
    # Criar arquivo como usuário www-data
    su -s /bin/bash -c "cat > /var/www/html/app/config/local.php" www-data << 'EOF'
<?php
$parameters = [
    'db_driver' => 'pdo_mysql',
    'db_host' => getenv('MAUTIC_DB_HOST'),
    'db_port' => getenv('MAUTIC_DB_PORT'),
    'db_name' => getenv('MAUTIC_DB_NAME'),
    'db_user' => getenv('MAUTIC_DB_USER'),
    'db_password' => getenv('MAUTIC_DB_PASSWORD'),
    'site_url' => getenv('MAUTIC_URL'),
    'install_source' => 'Docker',
    'skip_install' => true
];
EOF
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

# Iniciar Apache em foreground
apache2-foreground 