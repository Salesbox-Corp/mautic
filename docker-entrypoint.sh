#!/bin/bash
set -e

# Função para log com cores
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_warning() { echo -e "\033[0;33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERRO]\033[0m $1"; }

# Verificação inicial
log_info "Verificando montagem do EFS..."
if ! df -h | grep -q /mautic; then
    log_error "EFS não está montado em /mautic. Verifique a configuração do volume."
    exit 1
fi
log_success "EFS está montado em /mautic"

# Verificar e corrigir possíveis links simbólicos circulares
log_info "Verificando links simbólicos existentes..."
for link in "/var/www/html/media" "/var/www/html/app/config" "/var/www/html/app/cache" "/var/www/html/app/logs"; do
    if [ -L "$link" ]; then
        log_info "Removendo link simbólico existente: $link"
        rm -f "$link" || log_warning "Não foi possível remover link: $link"
    fi
done

# Verificar e corrigir possíveis links simbólicos circulares no EFS
log_info "Verificando diretórios no EFS..."
for dir in "/mautic/media" "/mautic/config" "/mautic/cache" "/mautic/logs"; do
    if [ -L "$dir" ]; then
        log_info "Removendo link simbólico no EFS: $dir"
        rm -f "$dir" || log_warning "Não foi possível remover link no EFS: $dir"
    fi
done

# Criar diretórios no EFS com tratamento de erro
log_info "Criando diretórios no EFS..."
for dir in "media" "config" "cache" "logs" "whitelabeler"; do
    if ! mkdir -p "/mautic/$dir" 2>/dev/null; then
        log_warning "Não foi possível criar diretório: /mautic/$dir"
        
        # Tentar corrigir o problema
        log_info "Tentando corrigir o diretório: /mautic/$dir"
        rm -rf "/mautic/$dir" 2>/dev/null
        if mkdir -p "/mautic/$dir" 2>/dev/null; then
            log_success "Diretório corrigido: /mautic/$dir"
        else
            log_error "Falha ao criar diretório: /mautic/$dir"
            # Continuar mesmo com erro
        fi
    else
        log_success "Diretório criado: /mautic/$dir"
    fi
done

# Backup dos dados originais (se existirem)
log_info "Verificando dados existentes..."

# Media
if [ -d "/var/www/html/media" ] && [ ! -L "/var/www/html/media" ] && [ "$(ls -A /var/www/html/media 2>/dev/null)" ]; then
    log_info "Copiando arquivos de media..."
    cp -a /var/www/html/media/* /mautic/media/ 2>/dev/null || log_warning "Erro ao copiar arquivos de media"
fi

# Config
if [ -d "/var/www/html/app/config" ] && [ ! -L "/var/www/html/app/config" ] && [ "$(ls -A /var/www/html/app/config 2>/dev/null)" ]; then
    log_info "Copiando arquivos de configuração..."
    cp -a /var/www/html/app/config/* /mautic/config/ 2>/dev/null || log_warning "Erro ao copiar arquivos de configuração"
fi

# Whitelabeler
if [ -d "/var/www/html/mautic-whitelabeler" ] && [ ! -L "/var/www/html/mautic-whitelabeler" ]; then
    log_info "Configurando mautic-whitelabeler..."
    # Se o diretório whitelabeler no EFS estiver vazio, copiar os arquivos
    if [ ! "$(ls -A /mautic/whitelabeler 2>/dev/null)" ]; then
        cp -a /var/www/html/mautic-whitelabeler/* /mautic/whitelabeler/ 2>/dev/null || log_warning "Erro ao copiar arquivos do whitelabeler"
    fi
    # Remover o diretório original para criar o link simbólico
    rm -rf /var/www/html/mautic-whitelabeler 2>/dev/null || log_warning "Erro ao remover diretório do whitelabeler"
fi

# Criar links simbólicos
log_info "Criando links simbólicos..."

# Função para criar link simbólico com segurança
create_symlink() {
    local target="$1"
    local link="$2"
    
    # Remover diretório original se existir
    if [ -d "$link" ] && [ ! -L "$link" ]; then
        rm -rf "$link" 2>/dev/null || log_warning "Não foi possível remover diretório: $link"
    fi
    
    # Remover link antigo se existir
    if [ -L "$link" ]; then
        rm -f "$link" 2>/dev/null || log_warning "Não foi possível remover link antigo: $link"
    fi
    
    # Criar novo link
    if ln -sf "$target" "$link" 2>/dev/null; then
        log_success "Link criado: $link -> $target"
    else
        log_warning "Não foi possível criar link: $link -> $target"
    fi
}

# Criar links para os diretórios principais
create_symlink "/mautic/media" "/var/www/html/media"
create_symlink "/mautic/config" "/var/www/html/app/config"
create_symlink "/mautic/cache" "/var/www/html/app/cache"
create_symlink "/mautic/logs" "/var/www/html/app/logs"
create_symlink "/mautic/whitelabeler" "/var/www/html/mautic-whitelabeler"

# Garantir arquivo .installed
log_info "Verificando arquivo .installed..."
touch /mautic/config/.installed 2>/dev/null || log_warning "Não foi possível criar arquivo .installed"

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