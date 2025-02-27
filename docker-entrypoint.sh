#!/bin/bash
set -e

# Configurar logo personalizado se a URL for fornecida
if [ ! -z "$MAUTIC_CUSTOM_LOGO_URL" ]; then
    echo "Configurando logo personalizado..."
    
    # Criar diretório para o logo se não existir
    mkdir -p /var/www/html/media/images
    
    # Baixar a imagem
    curl -s -L "$MAUTIC_CUSTOM_LOGO_URL" -o /var/www/html/media/images/custom_logo.png
    
    # Verificar se o download foi bem sucedido
    if [ $? -eq 0 ]; then
        # Atualizar configuração do Mautic para usar o logo personalizado
        sed -i "s|'logo_image' => '.*'|'logo_image' => 'images/custom_logo.png'|g" /var/www/html/app/config/local.php
        echo "Logo personalizado configurado com sucesso"
    else
        echo "Erro ao baixar logo personalizado. Usando logo padrão."
    fi
fi

# Iniciar Apache em foreground
apache2-foreground 