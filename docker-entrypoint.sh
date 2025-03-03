#!/bin/bash
set -e

# Função para log com cores
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_warning() { echo -e "\033[0;33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERRO]\033[0m $1"; }

# Verificação inicial
log_info "Verificando montagem do EFS..."
if ! df -h | grep -q /var/www/html; then
    log_warning "EFS pode não estar montado em /var/www/html. Verifique a configuração do volume."
    # Não vamos falhar aqui, pois pode ser uma execução local sem EFS
fi

# Criar diretórios essenciais se não existirem
log_info "Verificando diretórios essenciais..."
for dir in "/var/www/html/media" "/var/www/html/app/config" "/var/www/html/app/cache" "/var/www/html/app/logs" "/var/www/html/mautic-whitelabeler"; do
    if [ ! -d "$dir" ]; then
        log_info "Criando diretório: $dir"
        mkdir -p "$dir" 2>/dev/null || log_warning "Não foi possível criar diretório: $dir"
    fi
done

# Garantir arquivo .installed
log_info "Verificando arquivo .installed..."
touch /var/www/html/app/config/.installed 2>/dev/null || log_warning "Não foi possível criar arquivo .installed"

# Ajustar permissões apenas para o whitelabeler
log_info "Ajustando permissões para o whitelabeler..."
if [ -d "/var/www/html/mautic-whitelabeler" ]; then
    # Garantir que o diretório assets exista
    mkdir -p /var/www/html/mautic-whitelabeler/assets 2>/dev/null
    
    # Ajustar permissões apenas para o diretório do whitelabeler
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

log_success "Configuração de persistência concluída"
log_info "Iniciando processo principal..."

# Executar comando original
exec "$@"