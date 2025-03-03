#!/bin/bash
set -e

# Função para log com cores
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_warning() { echo -e "\033[0;33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERRO]\033[0m $1"; }

# Definir a variável de ambiente corretamente
export APACHE_DOCUMENT_ROOT="/var/www/html"

# Verificação inicial do EFS
log_info "Verificando montagem do EFS..."
if ! df -h | grep -q /var/www/html; then
    log_warning "EFS pode não estar montado em /var/www/html. Verifique a configuração do volume."
fi

# Criar link simbólico para o docroot
log_info "Verificando link simbólico para docroot..."
if [ ! -e "/var/www/html/docroot" ]; then
    log_info "Criando link simbólico de /var/www/html/docroot para /var/www/html..."
    # Remover o diretório docroot se existir
    rm -rf /var/www/html/docroot 2>/dev/null || true
    # Criar o link simbólico
    ln -sf /var/www/html /var/www/html/docroot
    log_success "Link simbólico criado com sucesso"
elif [ -L "/var/www/html/docroot" ]; then
    log_success "Link simbólico para docroot já existe"
else
    log_warning "Docroot existe mas não é um link simbólico. Isso pode causar problemas."
    log_info "Tentando corrigir o problema..."
    # Fazer backup do conteúdo
    mkdir -p /tmp/docroot_backup
    cp -a /var/www/html/docroot/* /tmp/docroot_backup/ 2>/dev/null || true
    # Remover o diretório
    rm -rf /var/www/html/docroot
    # Criar o link simbólico
    ln -sf /var/www/html /var/www/html/docroot
    # Restaurar o conteúdo para o diretório raiz
    cp -a /tmp/docroot_backup/* /var/www/html/ 2>/dev/null || true
    # Limpar o backup
    rm -rf /tmp/docroot_backup
    log_success "Problema corrigido, link simbólico criado"
fi

# Recriar completamente a configuração do Apache
log_info "Recriando configuração do Apache..."

# Fazer backup da configuração atual
cp /etc/apache2/sites-enabled/000-default.conf /etc/apache2/sites-enabled/000-default.conf.bak 2>/dev/null || true

# Criar uma nova configuração
cat > /etc/apache2/sites-enabled/000-default.conf << EOF
<VirtualHost *:80>
    ServerAdmin webmaster@localhost
    DocumentRoot ${APACHE_DOCUMENT_ROOT}
    
    <Directory ${APACHE_DOCUMENT_ROOT}>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
    </Directory>
    
    # Configuração adicional para o diretório docroot (link simbólico)
    <Directory ${APACHE_DOCUMENT_ROOT}/docroot>
        Options Indexes FollowSymLinks
        AllowOverride All
        Require all granted
        # Seguir links simbólicos
        Options +FollowSymLinks
    </Directory>
    
    ErrorLog \${APACHE_LOG_DIR}/error.log
    CustomLog \${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
EOF
log_success "Nova configuração do Apache criada com DocumentRoot: $APACHE_DOCUMENT_ROOT"

# Verificar e corrigir no apache2.conf se necessário
log_info "Verificando configuração em apache2.conf..."
if grep -q "<Directory /var/www/>" /etc/apache2/apache2.conf; then
    log_info "Atualizando configuração de diretório em apache2.conf..."
    # Garantir que a configuração do diretório /var/www/ permita seguir links simbólicos
    sed -i 's|<Directory /var/www/>.*Options Indexes FollowSymLinks|<Directory /var/www/>\n\tOptions Indexes FollowSymLinks|' /etc/apache2/apache2.conf
    sed -i 's|AllowOverride None|AllowOverride All|' /etc/apache2/apache2.conf
    log_success "Configuração de apache2.conf atualizada"
fi

# Habilitar módulos necessários do Apache
log_info "Habilitando módulos necessários do Apache..."
a2enmod rewrite headers ssl 2>/dev/null || log_warning "Não foi possível habilitar alguns módulos do Apache"
log_success "Módulos do Apache habilitados"

# Criar diretórios essenciais se não existirem
log_info "Verificando diretórios essenciais..."
for dir in "/var/www/html/media" "/var/www/html/config" "/var/www/html/var/cache" "/var/www/html/var/logs" "/var/www/html/mautic-whitelabeler"; do
    if [ ! -d "$dir" ]; then
        log_info "Criando diretório: $dir"
        mkdir -p "$dir" 2>/dev/null || log_warning "Não foi possível criar diretório: $dir"
    fi
done

# Garantir arquivo .installed
if [ ! -f "/var/www/html/config/.installed" ]; then
    log_info "Criando arquivo .installed..."
    touch /var/www/html/config/.installed 2>/dev/null || log_warning "Não foi possível criar arquivo .installed"
else
    log_success "Arquivo .installed já existe, pulando etapa."
fi

# Ajustar permissões apenas para o whitelabeler
log_info "Ajustando permissões para o whitelabeler..."
if [ -d "/var/www/html/mautic-whitelabeler" ]; then
    mkdir -p /var/www/html/mautic-whitelabeler/assets 2>/dev/null
    chmod -R 777 /var/www/html/mautic-whitelabeler 2>/dev/null || log_warning "Não foi possível ajustar permissões do whitelabeler"
    log_success "Permissões do whitelabeler ajustadas"
else
    log_warning "Diretório do whitelabeler não encontrado"
fi

# Verificar configuração do Apache para o whitelabeler
log_info "Verificando configuração do Apache para o whitelabeler..."
if [ -f "/etc/apache2/conf-available/mautic-whitelabeler.conf" ]; then
    if ! [ -f "/etc/apache2/conf-enabled/mautic-whitelabeler.conf" ]; then
        ln -sf /etc/apache2/conf-available/mautic-whitelabeler.conf /etc/apache2/conf-enabled/mautic-whitelabeler.conf
        log_success "Configuração do whitelabeler ativada"
    else
        log_success "Configuração do whitelabeler já está ativada"
    fi
else
    log_warning "Arquivo de configuração do whitelabeler não encontrado"
fi

# Ajustar permissões gerais
log_info "Ajustando permissões gerais..."
chown -R www-data:www-data /var/www/html 2>/dev/null || log_warning "Não foi possível ajustar permissões de proprietário"
chmod -R 755 /var/www/html 2>/dev/null || log_warning "Não foi possível ajustar permissões gerais"
log_success "Permissões ajustadas"

# Reiniciar Apache para garantir que as mudanças foram aplicadas
log_info "Reiniciando Apache..."
service apache2 restart
log_success "Apache reiniciado com sucesso"

log_success "Configuração de persistência concluída"
log_info "Iniciando processo principal..."

# Executar comando original
exec "$@"
