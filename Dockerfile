FROM php:8.3-apache

# Instalar dependências
RUN apt-get update && apt-get install -y \
    libzip-dev \
    zip \
    unzip \
    git \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libc-client-dev \
    libkrb5-dev \
    libmagickwand-dev \
    curl \
    libicu-dev \
    default-mysql-client \
    imagemagick \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-configure intl \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    zip \
    gd \
    imap \
    opcache \
    bcmath \
    sockets \
    intl

# Configurar PHP
RUN echo "memory_limit=512M" > /usr/local/etc/php/conf.d/memory-limit.ini \
    && echo "upload_max_filesize=128M" >> /usr/local/etc/php/conf.d/memory-limit.ini \
    && echo "post_max_size=128M" >> /usr/local/etc/php/conf.d/memory-limit.ini \
    && echo "max_execution_time=300" >> /usr/local/etc/php/conf.d/memory-limit.ini \
    && echo "zend.assertions=-1" >> /usr/local/etc/php/conf.d/memory-limit.ini

# Instalar Node.js e npm
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs

# Configurar Apache
RUN a2enmod rewrite

# Instalar Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Configurar diretório de trabalho
WORKDIR /var/www/html

# Copiar arquivos do projeto
COPY . .

# Instalar dependências com mais memória para o Composer
RUN php -d memory_limit=-1 /usr/bin/composer install --no-dev --optimize-autoloader

# Configurar permissões
RUN chown -R www-data:www-data . \
    && find . -type d -exec chmod 775 {} \; \
    && find . -type f -exec chmod 664 {} \;

# Criar diretórios necessários com permissões corretas
RUN mkdir -p /var/www/html/media \
    /var/www/html/app/config \
    /var/www/html/app/cache \
    /var/www/html/app/logs \
    /var/www/html/app/spool \
    && chown -R www-data:www-data /var/www/html \
    && chmod -R 775 /var/www/html/app/config \
    && chmod -R 775 /var/www/html/media \
    && chmod -R 775 /var/www/html/app/cache \
    && chmod -R 775 /var/www/html/app/logs \
    && chmod -R 775 /var/www/html/app/spool

# Copiar e configurar script de inicialização
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Definir script de inicialização
ENTRYPOINT ["docker-entrypoint.sh"] 