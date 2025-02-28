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

# Verificar se local.php existe e está íntegro
echo "=== Verificação do local.php ==="
if [ -f /var/www/html/app/config/local.php ]; then
    echo "local.php encontrado, verificando conteúdo:"
    cat /var/www/html/app/config/local.php | grep -v "password"
    echo "Permissões do local.php:"
    ls -l /var/www/html/app/config/local.php
else
    echo "local.php não encontrado, criando..."
fi

# Criar arquivo local.php com valores diretos
echo "Criando/atualizando arquivo local.php..."
cat > /var/www/html/app/config/local.php << EOF
<?php
\$parameters = array(
    'db_driver' => 'pdo_mysql',
    'db_host' => '${MAUTIC_DB_HOST}',
    'db_port' => ${MAUTIC_DB_PORT:-3306},
    'db_name' => '${MAUTIC_DB_NAME}',
    'db_user' => '${MAUTIC_DB_USER}',
    'db_password' => '${MAUTIC_DB_PASSWORD}',
    'db_table_prefix' => '${MAUTIC_DB_PREFIX}',
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
    'installed' => true,
    'is_installed' => true,
    'db_installed' => true,
    'install_source' => 'docker'
);
EOF

echo "Conteúdo atual do local.php (sem senhas):"
cat /var/www/html/app/config/local.php | grep -v "password"

# Ajustar permissões do local.php
chown www-data:www-data /var/www/html/app/config/local.php
chmod 644 /var/www/html/app/config/local.php

echo "Permissões finais do local.php:"
ls -l /var/www/html/app/config/local.php

# Verificar variáveis críticas
echo "=== Verificação de Variáveis Críticas ==="
echo "MAUTIC_URL: $MAUTIC_URL"
echo "MAUTIC_DB_HOST: $MAUTIC_DB_HOST"
echo "MAUTIC_DB_NAME: $MAUTIC_DB_NAME"
echo "MAUTIC_DB_USER: $MAUTIC_DB_USER"
echo "MAUTIC_ADMIN_EMAIL está definido: $([[ -n "$MAUTIC_ADMIN_EMAIL" ]] && echo "Sim" || echo "Não")"
echo "MAUTIC_ADMIN_PASSWORD está definido: $([[ -n "$MAUTIC_ADMIN_PASSWORD" ]] && echo "Sim" || echo "Não")"
echo "================================="

# Criar arquivo de healthcheck
echo "Criando arquivo de healthcheck..."
cat > /var/www/html/health.php << 'EOF'
<?php
header('Content-Type: application/json');
echo json_encode(['status' => 'healthy', 'timestamp' => time()]);
EOF

# Garantir permissões corretas
chown www-data:www-data /var/www/html/health.php
chmod 644 /var/www/html/health.php

echo "Arquivo health.php criado com permissões:"
ls -l /var/www/html/health.php

# Criar arquivo de teste para verificar se PHP está funcionando
echo "Criando arquivo de teste PHP..."
su -s /bin/bash -c "cat > /var/www/html/test.php" www-data << 'EOF'
<?php phpinfo(); ?>
EOF

# Testar conexão com o banco como www-data
echo "Testando conexão com o banco de dados como www-data..."
su -s /bin/bash www-data -c "mysql -h\"$MAUTIC_DB_HOST\" -P\"$MAUTIC_DB_PORT\" -u\"$MAUTIC_DB_USER\" -p\"$MAUTIC_DB_PASSWORD\" -e \"SELECT 1\" 2>&1" || echo "Falha na conexão como www-data"

# Configurar logo personalizado se a URL for fornecida
if [ ! -z "$MAUTIC_CUSTOM_LOGO_URL" ]; then
    echo "=== Configuração da Logo Personalizada ==="
    echo "URL da Logo: $MAUTIC_CUSTOM_LOGO_URL"
    
    # Criar diretório se não existir
    mkdir -p /var/www/html/media/images
    
    # Verificar se a imagem já existe e está íntegra
    if [ -f /var/www/html/media/images/custom_logo.png ]; then
        echo "Logo existente encontrada, verificando integridade..."
        if identify /var/www/html/media/images/custom_logo.png > /dev/null 2>&1; then
            echo "Logo existente está íntegra"
        else
            echo "Logo existente corrompida, será baixada novamente"
            rm -f /var/www/html/media/images/custom_logo.png
        fi
    fi
    
    # Baixar nova logo se necessário
    if [ ! -f /var/www/html/media/images/custom_logo.png ]; then
        echo "Baixando logo personalizada..."
        # Tratar URL com espaços
        FIXED_URL=$(echo "$MAUTIC_CUSTOM_LOGO_URL" | sed 's/ /%20/g')
        if curl -L -s "$FIXED_URL" -o /var/www/html/media/images/custom_logo.png; then
            # Verificar se o download foi bem sucedido
            if identify /var/www/html/media/images/custom_logo.png > /dev/null 2>&1; then
                echo "Logo baixada com sucesso"
                # Atualizar configuração do Mautic para usar o logo personalizado
                su -s /bin/bash -c "sed -i \"/\\\$parameters = \[/a\    'logo_image' => 'images/custom_logo.png',\" /var/www/html/app/config/local.php" www-data
                echo "Configuração da logo atualizada no local.php"
            else
                echo "Logo baixada está corrompida, usando logo padrão..."
                rm -f /var/www/html/media/images/custom_logo.png
            fi
        else
            echo "Erro ao baixar logo personalizada, pulando configuração da logo..."
        fi
    fi
    
    # Verificar permissões
    if [ -f /var/www/html/media/images/custom_logo.png ]; then
        chown www-data:www-data /var/www/html/media/images/custom_logo.png
        chmod 664 /var/www/html/media/images/custom_logo.png
        
        echo "Status final da logo:"
        ls -l /var/www/html/media/images/custom_logo.png
    else
        echo "Aviso: Nenhuma logo foi configurada"
    fi
    echo "=== Fim da Configuração da Logo ==="
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

# Criar arquivo de teste PHP
echo "Criando arquivo info.php para diagnóstico..."
cat > /var/www/html/info.php << 'EOF'
<?php
echo "PHP está funcionando!<br>";
phpinfo();
EOF

chown www-data:www-data /var/www/html/info.php
chmod 644 /var/www/html/info.php

echo "Arquivo info.php criado com permissões:"
ls -l /var/www/html/info.php

# Aguardar o banco de dados estar disponível
if [ ! -z "$MAUTIC_DB_HOST" ]; then
    echo "Aguardando banco de dados..."
    while ! mysqladmin ping -h"$MAUTIC_DB_HOST" -P"${MAUTIC_DB_PORT:-3306}" --silent; do
        sleep 1
    done
fi

cd /var/www/html

# Verificar se o Mautic já está instalado
if [ ! -f "docroot/app/config/local.php" ]; then
    echo "Instalando Mautic..."
    
    # Instalar Mautic via CLI
    php bin/console mautic:install "$MAUTIC_URL" \
        --mailer_from_name="$MAUTIC_ADMIN_FROM_NAME" \
        --mailer_from_email="$MAUTIC_ADMIN_FROM_EMAIL" \
        --mailer_transport="$MAUTIC_MAILER_TRANSPORT" \
        --mailer_host="$MAUTIC_MAILER_HOST" \
        --mailer_port="$MAUTIC_MAILER_PORT" \
        --db_driver="pdo_mysql" \
        --db_host="$MAUTIC_DB_HOST" \
        --db_port="$MAUTIC_DB_PORT" \
        --db_name="$MAUTIC_DB_NAME" \
        --db_user="$MAUTIC_DB_USER" \
        --db_password="$MAUTIC_DB_PASSWORD" \
        --admin_email="$MAUTIC_ADMIN_EMAIL" \
        --admin_password="$MAUTIC_ADMIN_PASSWORD" \
        --admin_firstname="$MAUTIC_ADMIN_FIRSTNAME" \
        --admin_lastname="$MAUTIC_ADMIN_LASTNAME" \
        --db_backup_tables="false"
fi

# Limpar cache
rm -rf docroot/app/cache/*

# Ajustar permissões
chown -R www-data:www-data .
find . -type d -exec chmod 775 {} \;
find . -type f -exec chmod 664 {} \;

# Garantir que o diretório de cache existe e tem as permissões corretas
mkdir -p /var/www/html/app/cache
chmod -R 777 /var/www/html/app/cache

# Criar arquivo .installed se não existir
touch /var/www/html/app/config/.installed
chown www-data:www-data /var/www/html/app/config/.installed
chmod 644 /var/www/html/app/config/.installed

# Garantir que o local.php tem as permissões corretas
chown www-data:www-data /var/www/html/app/config/local.php
chmod 644 /var/www/html/app/config/local.php

# Limpar cache do Mautic
rm -rf /var/www/html/app/cache/*

# Executar o comando original
exec "$@" 