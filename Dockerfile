FROM mautic/mautic:5.2.3-apache

# Instalar ferramentas necessárias
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    imagemagick \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Definir diretório de trabalho
WORKDIR /var/www/html

# Criar diretórios necessários
RUN mkdir -p /var/www/html/media/images \
    && mkdir -p /var/www/html/app/assets/images \
    && mkdir -p /var/www/html/app/assets/images/themes/blank

# Copiar apenas os arquivos necessários
COPY local.php /var/www/html/app/config/
COPY assets/default_logo.png /var/www/html/app/assets/images/mautic_logo.png
COPY assets/default_logo.png /var/www/html/media/images/mautic_logo_db.png
COPY assets/default_logo.png /var/www/html/app/assets/images/themes/blank/mautic_logo.png
COPY docker-entrypoint.sh /usr/local/bin/

# Configurar permissões
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 775 {} \; \
    && find /var/www/html -type f -exec chmod 664 {} \; \
    && chmod 644 /var/www/html/app/assets/images/mautic_logo.png \
    && chmod 644 /var/www/html/media/images/mautic_logo_db.png \
    && chmod 644 /var/www/html/app/assets/images/themes/blank/mautic_logo.png \
    && chmod +x /usr/local/bin/docker-entrypoint.sh

# Definir script de inicialização
ENTRYPOINT ["docker-entrypoint.sh"]

# Comando para iniciar o Apache
CMD ["apache2-foreground"] 