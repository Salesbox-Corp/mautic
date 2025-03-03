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

# Parar Apache temporariamente
log_info "Parando Apache temporariamente..."
service apache2 stop || log_warning "Apache não pôde ser parado"

# Diretórios essenciais para persistência
log_info "Configurando persistência básica..."

# 1. Criar diretórios essenciais no EFS
log_info "Criando diretórios essenciais no EFS..."
mkdir -p /mautic/media 2>/dev/null || log_warning "Diretório media já existe"
mkdir -p /mautic/config 2>/dev/null || log_warning "Diretório config já existe"
mkdir -p /mautic/cache 2>/dev/null || log_warning "Diretório cache já existe"
mkdir -p /mautic/logs 2>/dev/null || log_warning "Diretório logs já existe"

# 2. Garantir que o Mautic tenha os diretórios necessários
log_info "Verificando diretórios do Mautic..."
mkdir -p /var/www/html/app/config 2>/dev/null || log_warning "Diretório app/config já existe"
mkdir -p /var/www/html/app/cache 2>/dev/null || log_warning "Diretório app/cache já existe"
mkdir -p /var/www/html/app/logs 2>/dev/null || log_warning "Diretório app/logs já existe"
mkdir -p /var/www/html/media 2>/dev/null || log_warning "Diretório media já existe"

# 3. Copiar dados existentes para o EFS (apenas na primeira execução)
log_info "Copiando dados existentes para o EFS (se necessário)..."
if [ -d "/var/www/html/media" ] && [ ! -L "/var/www/html/media" ] && [ "$(ls -A /var/www/html/media 2>/dev/null)" ]; then
    log_info "Copiando arquivos de media para o EFS..."
    cp -a /var/www/html/media/* /mautic/media/ 2>/dev/null || log_warning "Erro ao copiar arquivos de media"
fi

if [ -d "/var/www/html/app/config" ] && [ ! -L "/var/www/html/app/config" ] && [ "$(ls -A /var/www/html/app/config 2>/dev/null)" ]; then
    log_info "Copiando arquivos de configuração para o EFS..."
    cp -a /var/www/html/app/config/* /mautic/config/ 2>/dev/null || log_warning "Erro ao copiar arquivos de configuração"
fi

# 4. Remover diretórios originais e criar links simbólicos
log_info "Configurando links simbólicos..."

# Media
if [ -d "/var/www/html/media" ] && [ ! -L "/var/www/html/media" ]; then
    rm -rf /var/www/html/media
    log_info "Diretório media removido"
fi
ln -sf /mautic/media /var/www/html/media
log_success "Link para media criado"

# Config
if [ -d "/var/www/html/app/config" ] && [ ! -L "/var/www/html/app/config" ]; then
    rm -rf /var/www/html/app/config
    log_info "Diretório config removido"
fi
ln -sf /mautic/config /var/www/html/app/config
log_success "Link para config criado"

# Cache
if [ -d "/var/www/html/app/cache" ] && [ ! -L "/var/www/html/app/cache" ]; then
    rm -rf /var/www/html/app/cache
    log_info "Diretório cache removido"
fi
ln -sf /mautic/cache /var/www/html/app/cache
log_success "Link para cache criado"

# Logs
if [ -d "/var/www/html/app/logs" ] && [ ! -L "/var/www/html/app/logs" ]; then
    rm -rf /var/www/html/app/logs
    log_info "Diretório logs removido"
fi
ln -sf /mautic/logs /var/www/html/app/logs
log_success "Link para logs criado"

# 5. Garantir arquivo .installed
log_info "Verificando arquivo .installed..."
touch /mautic/config/.installed 2>/dev/null || log_warning "Não foi possível criar arquivo .installed"

# 6. Ajustar permissões
log_info "Ajustando permissões..."
chown -R www-data:www-data /mautic 2>/dev/null || log_warning "Erro ao ajustar proprietário"
chmod -R 775 /mautic 2>/dev/null || log_warning "Erro ao ajustar permissões"

# 7. Iniciar Apache
log_info "Iniciando Apache..."
service apache2 start || log_error "Erro ao iniciar Apache"

log_success "Configuração de persistência concluída"

# Executar comando original
exec "$@"