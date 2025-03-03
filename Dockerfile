FROM mautic/mautic:5.2.3-apache

# Instalar ferramentas necessárias
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    imagemagick \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Definir diretório de trabalho
WORKDIR /var/www/html

# Criar diretórios básicos
RUN mkdir -p /var/www/html/app/cache /var/www/html/app/logs \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html

# Copiar script de inicialização
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Não definimos o usuário como www-data para permitir que o Apache possa vincular à porta 80
# O Apache internamente mudará para www-data após vincular às portas

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]