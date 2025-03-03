FROM mautic/mautic:5.2.3-apache

# Instalar ferramentas necessárias
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    imagemagick \
    curl \
    git \
    unzip \
    && rm -rf /var/lib/apt/lists/*

# Definir diretório de trabalho
WORKDIR /var/www/html

# Criar diretórios básicos
RUN mkdir -p /var/www/html/app/cache /var/www/html/app/logs

# Instalar mautic-whitelabeler usando curl em vez de git
RUN curl -L -o /tmp/mautic-whitelabeler.zip https://github.com/nickian/mautic-whitelabeler/archive/refs/heads/master.zip \
    && unzip /tmp/mautic-whitelabeler.zip -d /tmp \
    && mv /tmp/mautic-whitelabeler-master /var/www/html/mautic-whitelabeler \
    && rm /tmp/mautic-whitelabeler.zip

# Copiar configuração do mautic-whitelabeler
COPY mautic-whitelabeler.conf /etc/apache2/conf-available/
RUN ln -sf /etc/apache2/conf-available/mautic-whitelabeler.conf /etc/apache2/conf-enabled/mautic-whitelabeler.conf

# Copiar arquivo local.php.dist personalizado
COPY local.php.dist /var/www/html/app/config/local.php.dist

# Definir variáveis de ambiente para evitar reinstalação
ENV MAUTIC_SKIP_INSTALL=true
ENV MAUTIC_INSTALL_SOURCE=TERRAFORM

# Copiar script de inicialização
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Não definimos o usuário como www-data para permitir que o Apache possa vincular à porta 80
# O Apache internamente mudará para www-data após vincular às portas

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["apache2-foreground"]