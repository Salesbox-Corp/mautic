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
    && mkdir -p /var/www/html/app/assets/images/themes/blank \
    && mkdir -p /var/www/html/app/config

# Criar arquivo .installed e ajustar permissões de cache
RUN touch /var/www/html/app/config/.installed \
    && mkdir -p /var/www/html/app/cache \
    && chmod -R 777 /var/www/html/app/cache \
    && chown -R www-data:www-data /var/www/html/app/cache

# Copiar arquivos de configuração primeiro
COPY local.php /var/www/html/app/config/
RUN chown www-data:www-data /var/www/html/app/config/local.php \
    && chmod 644 /var/www/html/app/config/local.php \
    && chown www-data:www-data /var/www/html/app/config/.installed \
    && chmod 644 /var/www/html/app/config/.installed

# Copiar logos e scripts
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

# Verificar conteúdo do local.php após a cópia
RUN echo "Verificando local.php após a cópia:" && \
    cat /var/www/html/app/config/local.php | grep -v password && \
    echo "Permissões do local.php:" && \
    ls -l /var/www/html/app/config/local.php

# Criar script para logar o local.php na inicialização
RUN echo '#!/bin/bash\necho "=== Conteúdo do local.php na inicialização ==="\ncat /var/www/html/app/config/local.php | grep -v password\necho "=== Fim do local.php ==="\nexec "$@"' > /usr/local/bin/docker-entrypoint-wrapper.sh \
    && chmod +x /usr/local/bin/docker-entrypoint-wrapper.sh

# Definir script de inicialização
ENTRYPOINT ["/usr/local/bin/docker-entrypoint-wrapper.sh", "/usr/local/bin/docker-entrypoint.sh"]

# Comando para iniciar o Apache
CMD ["apache2-foreground"] 