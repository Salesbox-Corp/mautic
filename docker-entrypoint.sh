#!/bin/bash
set -e

# Criar diretório de configuração se não existir
mkdir -p /var/www/html/app/config

# Criar arquivo local.php com configurações básicas se não existir
if [ ! -f /var/www/html/app/config/local.php ]; then
    echo "<?php
\$parameters = [
    'db_driver' => 'pdo_mysql',
    'db_host' => getenv('MAUTIC_DB_HOST'),
    'db_port' => getenv('MAUTIC_DB_PORT'),
    'db_name' => getenv('MAUTIC_DB_NAME'),
    'db_user' => getenv('MAUTIC_DB_USER'),
    'db_password' => getenv('MAUTIC_DB_PASSWORD'),
    'site_url' => getenv('MAUTIC_URL'),
];" > /var/www/html/app/config/local.php
fi

# Configurar logo personalizado se a URL for fornecida
if [ ! -z "$MAUTIC_CUSTOM_LOGO_URL" ]; then
    echo "Configurando logo personalizado..."
    
    # Criar diretório para o logo se não existir
    mkdir -p /var/www/html/media/images
    
    # Baixar a imagem
    curl -s -L "$MAUTIC_CUSTOM_LOGO_URL" -o /var/www/html/media/images/custom_logo.png
    
    # Verificar se o download foi bem sucedido
    if [ $? -eq 0 ]; then
        # Atualizar configuração do Mautic para usar o logo personalizado
        sed -i "/\$parameters = \[/a\    'logo_image' => 'images/custom_logo.png'," /var/www/html/app/config/local.php
        echo "Logo personalizado configurado com sucesso"
    else
        echo "Erro ao baixar logo personalizado. Usando logo padrão."
    fi
fi

# Iniciar Apache em foreground
apache2-foreground 