FROM mautic/mautic:5.2.3-apache

# Instalar ferramentas necessárias
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    imagemagick \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Definir diretório de trabalho
WORKDIR /var/www/html

# Criar diretórios básicos
RUN mkdir -p /var/www/html/app/cache \
    && mkdir -p /var/www/html/app/logs \
    && chown -R www-data:www-data /var/www/html/app/cache /var/www/html/app/logs \
    && chmod -R 775 /var/www/html/app/cache /var/www/html/app/logs

# Copiar script de inicialização
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Definir script de inicialização
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Comando para iniciar o Apache
CMD ["apache2-foreground"] 