FROM mautic/mautic:5.2.3-apache

# Instalar ferramentas necessárias
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    imagemagick \
    curl \
    jq \
    awscli \
    git \
    && rm -rf /var/lib/apt/lists/*

# Instalar Whitelabeler
RUN cd /var/www/html && \
    git clone https://github.com/nickian/mautic-whitelabeler.git && \
    chown -R www-data:www-data mautic-whitelabeler

# Definir diretório de trabalho
WORKDIR /var/www/html

# Criar diretórios necessários (exceto os que serão montados via EFS)
RUN mkdir -p /var/www/html/app/assets/images \
    && mkdir -p /var/www/html/app/assets/images/themes/blank \
    && mkdir -p /var/www/html/app/config \
    && mkdir -p /var/www/html/app/cache \
    && mkdir -p /var/www/html/app/logs \
    && mkdir -p /var/www/html/app/spool

# Criar arquivo .installed e ajustar permissões de cache
RUN touch /var/www/html/app/config/.installed \
    && chmod -R 777 /var/www/html/app/cache \
    && chown -R www-data:www-data /var/www/html/app/cache

# Copiar logos para diretórios não-EFS
COPY assets/default_logo.png /var/www/html/app/assets/images/mautic_logo.png
COPY assets/default_logo.png /var/www/html/app/assets/images/themes/blank/mautic_logo.png

# Copiar scripts
COPY docker-entrypoint.sh /usr/local/bin/
COPY scripts/manage-database.sh /usr/local/bin/

# Configurar permissões
RUN chown -R www-data:www-data /var/www/html \
    && find /var/www/html -type d -exec chmod 775 {} \; \
    && find /var/www/html -type f -exec chmod 664 {} \; \
    && chmod 644 /var/www/html/app/assets/images/mautic_logo.png \
    && chmod 644 /var/www/html/app/assets/images/themes/blank/mautic_logo.png \
    && chmod +x /usr/local/bin/docker-entrypoint.sh \
    && chmod +x /usr/local/bin/manage-database.sh

# Definir script de inicialização
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Comando para iniciar o Apache
CMD ["apache2-foreground"] 