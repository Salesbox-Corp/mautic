#!/bin/bash
set -e

# Função para log com cores
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_warning() { echo -e "\033[0;33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERRO]\033[0m $1"; }

log_info "Ajustando permissões..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html

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

# Executar comando original
exec "$@"