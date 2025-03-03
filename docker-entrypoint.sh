#!/bin/bash
set -e

# Função para log com cores
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_warning() { echo -e "\033[0;33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERRO]\033[0m $1"; }

# Definir a variável de ambiente corretamente
export APACHE_DOCUMENT_ROOT="/var/www/html"

# Garantir que o Apache use esse caminho no VirtualHost
log_info "Definindo DocumentRoot no Apache..."
# Primeiro, verifique qual é o DocumentRoot atual
CURRENT_DOCROOT=$(grep -o 'DocumentRoot [^ ]*' /etc/apache2/sites-enabled/000-default.conf | awk '{print $2}')
log_info "DocumentRoot atual: $CURRENT_DOCROOT"

# Substitua qualquer DocumentRoot pelo valor correto
sed -i 's|DocumentRoot [^ ]*|DocumentRoot '"$APACHE_DOCUMENT_ROOT"'|' /etc/apache2/sites-enabled/000-default.conf
log_success "DocumentRoot atualizado para $APACHE_DOCUMENT_ROOT"

# Verificação inicial do EFS
log_info "Verificando montagem do EFS..."
if ! df -h | grep -q /var/www/html; then
    log_warning "EFS pode não estar montado em /var/www/html. Verifique a configuração do volume."
fi

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

# Reiniciar Apache para garantir que as mudanças foram aplicadas
log_info "Reiniciando Apache..."
service apache2 restart
log_success "Apache reiniciado com sucesso"

log_success "Configuração de persistência concluída"
log_info "Iniciando processo principal..."

# Executar comando original
exec "$@"
