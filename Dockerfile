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
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-configure imap --with-kerberos --with-imap-ssl \
    && docker-php-ext-install -j$(nproc) \
    pdo_mysql \
    zip \
    gd \
    imap \
    opcache \
    bcmath \
    sockets

# Configurar PHP
RUN echo "memory_limit=512M" > /usr/local/etc/php/conf.d/memory-limit.ini \
    && echo "upload_max_filesize=128M" >> /usr/local/etc/php/conf.d/memory-limit.ini \
    && echo "post_max_size=128M" >> /usr/local/etc/php/conf.d/memory-limit.ini \
    && echo "max_execution_time=300" >> /usr/local/etc/php/conf.d/memory-limit.ini

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
RUN chown -R www-data:www-data .

# Criar diretório de mídia com permissões corretas
RUN mkdir -p /var/www/html/media && \
    chown -R www-data:www-data /var/www/html/media && \
    chmod -R 755 /var/www/html/media

# Copiar e configurar script de inicialização
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Definir script de inicialização
ENTRYPOINT ["docker-entrypoint.sh"] 