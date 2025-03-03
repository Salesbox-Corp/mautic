#!/bin/bash
set -e

# Função para log com cores
log_info() { echo -e "\033[0;34m[INFO]\033[0m $1"; }
log_success() { echo -e "\033[0;32m[OK]\033[0m $1"; }
log_warning() { echo -e "\033[0;33m[AVISO]\033[0m $1"; }
log_error() { echo -e "\033[0;31m[ERRO]\033[0m $1"; }

# Função para executar comando com tratamento de erro
execute_safe() {
    local cmd="$1"
    local msg_success="$2"
    local msg_error="$3"
    
    if eval "$cmd" 2>/dev/null; then
        log_success "$msg_success"
        return 0
    else
        log_warning "$msg_error"
        return 1
    fi
}

# Lista de diretórios para persistência
PERSIST_DIRS=(
    "media"
    "config:app/config"
    "cache:app/cache"
    "logs:app/logs"
    "plugins"
    "translations"
)

# Debug inicial
log_info "=== Verificação Inicial ==="
df -h | grep /mautic && log_success "EFS está montado" || log_warning "EFS não está montado"
ls -la /var/www/html || log_warning "Diretório Mautic não encontrado"

# Parar Apache
log_info "Parando Apache temporariamente..."
execute_safe "service apache2 stop" \
    "Apache parado com sucesso" \
    "Apache não pôde ser parado, continuando mesmo assim"

# Aguardar montagem do EFS
log_info "Aguardando montagem do EFS..."
for i in {1..30}; do
    if df -h | grep -q /mautic; then
        log_success "EFS detectado e montado"
        break
    fi
    log_info "Tentativa $i/30 - Aguardando EFS..."
    sleep 1
done

# Verificar montagem do EFS
if ! df -h | grep -q /mautic; then
    log_error "EFS não foi montado corretamente"
    exit 1
fi

# Remover links simbólicos antigos e criar estrutura
log_info "Configurando diretórios e links..."
for dir_map in "${PERSIST_DIRS[@]}"; do
    # Separar diretório EFS e caminho Mautic
    efs_dir=$(echo $dir_map | cut -d: -f1)
    mautic_path=$(echo $dir_map | cut -d: -f2)
    # Se não houver caminho específico, usar o mesmo nome
    mautic_path=${mautic_path:-$efs_dir}
    
    # Caminho completo
    efs_path="/mautic/$efs_dir"
    mautic_full_path="/var/www/html/$mautic_path"
    
    # Criar diretório no EFS
    execute_safe "mkdir -p '$efs_path'" \
        "Diretório criado: $efs_path" \
        "Não foi possível criar diretório: $efs_path"
    
    # Remover link antigo se existir
    if [ -L "$mautic_full_path" ]; then
        execute_safe "rm -f '$mautic_full_path'" \
            "Link antigo removido: $mautic_full_path" \
            "Não foi possível remover link antigo: $mautic_full_path"
    elif [ -d "$mautic_full_path" ]; then
        execute_safe "rm -rf '$mautic_full_path'" \
            "Diretório antigo removido: $mautic_full_path" \
            "Não foi possível remover diretório antigo: $mautic_full_path"
    fi
    
    # Criar novo link simbólico
    execute_safe "ln -sf '$efs_path' '$mautic_full_path'" \
        "Link criado: $mautic_full_path -> $efs_path" \
        "Não foi possível criar link: $mautic_full_path"
done

# Ajustar permissões
log_info "Ajustando permissões..."
execute_safe "find /mautic -type d -exec chmod 775 {} +" \
    "Permissões de diretórios ajustadas" \
    "Erro ao ajustar permissões de alguns diretórios"
execute_safe "find /mautic -type f -exec chmod 664 {} +" \
    "Permissões de arquivos ajustadas" \
    "Erro ao ajustar permissões de alguns arquivos"
execute_safe "chown -R www-data:www-data /mautic" \
    "Propriedade dos arquivos ajustada" \
    "Erro ao ajustar propriedade de alguns arquivos"

# Configurar arquivo .installed
log_info "Configurando arquivo .installed..."
execute_safe "touch /mautic/config/.installed" \
    "Arquivo .installed criado" \
    "Não foi possível criar arquivo .installed"
execute_safe "chown www-data:www-data /mautic/config/.installed" \
    "Propriedade do .installed ajustada" \
    "Erro ao ajustar propriedade do .installed"
execute_safe "chmod 664 /mautic/config/.installed" \
    "Permissões do .installed ajustadas" \
    "Erro ao ajustar permissões do .installed"

# Configurar local.php
if [ ! -f "/mautic/config/local.php" ]; then
    log_info "Configurando local.php..."
    if [ -f "/var/www/html/app/config/local.php.dist" ]; then
        execute_safe "cp /var/www/html/app/config/local.php.dist /mautic/config/local.php" \
            "local.php copiado do template" \
            "Erro ao copiar local.php do template"
    else
        log_info "Criando local.php padrão..."
        cat > /mautic/config/local.php << 'EOF' || log_warning "Erro ao criar local.php"
<?php
$parameters = array(
    'db_driver' => 'pdo_mysql',
    'db_host' => getenv('MAUTIC_DB_HOST'),
    'db_port' => getenv('MAUTIC_DB_PORT'),
    'db_name' => getenv('MAUTIC_DB_NAME'),
    'db_user' => getenv('MAUTIC_DB_USER'),
    'db_password' => getenv('MAUTIC_DB_PASSWORD'),
    'db_table_prefix' => getenv('MAUTIC_TABLE_PREFIX'),
    'db_backup_tables' => 1,
    'db_backup_prefix' => 'bak_',
    'admin_email' => getenv('MAUTIC_ADMIN_EMAIL'),
    'admin_password' => getenv('MAUTIC_ADMIN_PASSWORD'),
    'site_url' => getenv('MAUTIC_URL')
);
EOF
    fi
    execute_safe "chown www-data:www-data /mautic/config/local.php" \
        "Propriedade do local.php ajustada" \
        "Erro ao ajustar propriedade do local.php"
    execute_safe "chmod 664 /mautic/config/local.php" \
        "Permissões do local.php ajustadas" \
        "Erro ao ajustar permissões do local.php"
fi

# Iniciar Apache
log_info "Iniciando Apache..."
execute_safe "service apache2 start" \
    "Apache iniciado com sucesso" \
    "Erro ao iniciar Apache"

log_success "Configuração concluída"
exec "$@"