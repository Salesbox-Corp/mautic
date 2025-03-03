FROM mautic/mautic:5.2.3-apache

# Instalar ferramentas necessárias em um único comando para reduzir camadas
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    imagemagick \
    curl \
    git \
    && rm -rf /var/lib/apt/lists/*

# Definir diretório de trabalho
WORKDIR /var/www/html

# Instalar Whitelabeler apenas se não existir
RUN if [ ! -d "/var/www/html/mautic-whitelabeler" ]; then \
    git clone https://github.com/nickian/mautic-whitelabeler.git /var/www/html/mautic-whitelabeler; \
    chown -R www-data:www-data /var/www/html/mautic-whitelabeler; \
fi

# Criar e copiar a configuração do Apache para Whitelabeler
COPY mautic-whitelabeler.conf /etc/apache2/conf-available/mautic-whitelabeler.conf
RUN a2enconf mautic-whitelabeler

# Criar diretórios básicos e configurar permissões
RUN mkdir -p /var/www/html/app/cache /var/www/html/app/logs \
    && chown -R www-data:www-data /var/www/html/app/cache /var/www/html/app/logs \
    && chmod -R 775 /var/www/html/app/cache /var/www/html/app/logs

# Copiar script de inicialização
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Definir usuário não-root para execução segura
USER www-data

# Definir script de inicialização
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Comando para iniciar o Apache
CMD ["apache2-foreground"]