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
for dir in "media" "config" "cache" "logs"; do
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

# Garantir arquivo .installed
log_info "Verificando arquivo .installed..."
touch /mautic/config/.installed 2>/dev/null || log_warning "Não foi possível criar arquivo .installed"

# Ajustar permissões
log_info "Ajustando permissões..."
chown -R www-data:www-data /mautic 2>/dev/null || log_warning "Erro ao ajustar proprietário"
chmod -R 775 /mautic 2>/dev/null || log_warning "Erro ao ajustar permissões"

# Verificar e corrigir configuração do Apache
log_info "Verificando configuração do Apache..."

# Verificar se a variável APACHE_DOCUMENT_ROOT está definida
if grep -q '\${APACHE_DOCUMENT_ROOT}' /etc/apache2/sites-available/000-default.conf; then
    log_info "Corrigindo configuração do Apache..."
    # Substituir a variável não definida pelo caminho correto
    sed -i 's|\${APACHE_DOCUMENT_ROOT}|/var/www/html|g' /etc/apache2/sites-available/000-default.conf || log_warning "Não foi possível corrigir a configuração do Apache"
fi

# Garantir que o Apache possa ser executado como www-data
log_info "Ajustando permissões do Apache..."
chown -R www-data:www-data /var/log/apache2 2>/dev/null || log_warning "Não foi possível ajustar permissões de logs do Apache"
chown -R www-data:www-data /var/run/apache2 2>/dev/null || log_warning "Não foi possível ajustar permissões de run do Apache"

# Executar o Apache como comando original em vez de tentar iniciá-lo aqui
log_success "Configuração de persistência concluída"
log_info "Iniciando Apache como processo principal..."

# Executar comando original (que deve ser apache2-foreground)
exec "$@"