FROM mautic/mautic:5.2.3-apache

# Instalar ferramentas necessárias
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    imagemagick \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Criar diretório para logo padrão
RUN mkdir -p /var/www/html/media/images

# Copiar arquivos de configuração
COPY local.php /var/www/html/app/config/
COPY . .

# Configurar permissões
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 775 {} \; \
    && find /var/www/html -type f -exec chmod 664 {} \;

# Copiar e configurar script de inicialização
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Definir script de inicialização
ENTRYPOINT ["docker-entrypoint.sh"] 