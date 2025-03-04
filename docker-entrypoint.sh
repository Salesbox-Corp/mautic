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
    log_error "EFS não está montado em /var/www/html. Verifique a configuração do volume."
    exit 1
fi
log_success "EFS está montado em /var/www/html"

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
for dir in "/var/www/html/media" "/var/www/html/app/config" "/var/www/html/app/cache" "/var/www/html/app/logs"; do
    if [ -L "$dir" ]; then
        log_info "Removendo link simbólico no EFS: $dir"
        rm -f "$dir" || log_warning "Não foi possível remover link no EFS: $dir"
    fi
done

# Criar diretórios no EFS com tratamento de erro
log_info "Criando diretórios no EFS..."
for dir in "media" "app/config" "app/cache" "app/logs"; do
    if ! mkdir -p "/var/www/html/$dir" 2>/dev/null; then
        log_warning "Não foi possível criar diretório: /var/www/html/$dir"
        
        # Tentar corrigir o problema
        log_info "Tentando corrigir o diretório: /var/www/html/$dir"
        rm -rf "/var/www/html/$dir" 2>/dev/null
        if mkdir -p "/var/www/html/$dir" 2>/dev/null; then
            log_success "Diretório corrigido: /var/www/html/$dir"
        else
            log_error "Falha ao criar diretório: /var/www/html/$dir"
            # Continuar mesmo com erro
        fi
    else
        log_success "Diretório criado: /var/www/html/$dir"
    fi
done

# Como o EFS já está em /var/www/html, não precisamos mais de backup ou links simbólicos
log_info "O EFS já está montado no diretório de trabalho, não é necessário criar links simbólicos"

# Garantir arquivo .installed
log_info "Verificando arquivo .installed..."
touch /var/www/html/app/config/.installed 2>/dev/null || log_warning "Não foi possível criar arquivo .installed"

# Ajustar permissões do EFS
log_info "Ajustando permissões do EFS..."
chown -R www-data:www-data /var/www/html
chmod -R 777 /var/www/html 2>/dev/null || log_warning "Erro ao ajustar permissões do EFS"

# Configurar Apache para usar porta 8080
log_info "Configurando porta do Apache..."
if [ -f /etc/apache2/ports.conf ]; then
    sed -i 's/Listen 80/Listen 8080/g' /etc/apache2/ports.conf 2>/dev/null || log_warning "Não foi possível alterar a porta do Apache"
fi

log_success "Configuração de persistência concluída"
log_info "Iniciando processo principal na porta 8080..."

# Executar comando original
exec "$@"