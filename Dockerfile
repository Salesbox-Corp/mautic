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

# Criar diretórios essenciais (ajustados para estrutura correta do Mautic)
RUN mkdir -p /var/www/html/media /var/www/html/app/config /var/www/html/app/cache /var/www/html/app/logs

# Instalar mautic-whitelabeler usando curl em vez de git
RUN curl -L -o /tmp/mautic-whitelabeler.zip https://github.com/nickian/mautic-whitelabeler/archive/refs/heads/master.zip \
    && unzip /tmp/mautic-whitelabeler.zip -d /tmp \
    && mv /tmp/mautic-whitelabeler-master /var/www/html/mautic-whitelabeler \
    && rm /tmp/mautic-whitelabeler.zip

# Copiar configuração do mautic-whitelabeler
COPY mautic-whitelabeler.conf /etc/apache2/conf-available/
RUN ln -sf /etc/apache2/conf-available/mautic-whitelabeler.conf /etc/apache2/conf-enabled/mautic-whitelabeler.conf

# Definir variáveis de ambiente para evitar reinstalação
ENV MAUTIC_SKIP_INSTALL=true
ENV MAUTIC_INSTALL_SOURCE=TERRAFORM

# Copiar script de inicialização corrigido
COPY docker-entrypoint.sh /usr/local/bin/
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Garantir que o Mautic não tente sobrescrever o EFS, copiando apenas se o volume estiver vazio
RUN echo '#!/bin/bash\n\
if [ -z "$(ls -A /var/www/html)" ]; then\n\
    echo "Diretório vazio, copiando arquivos do Mautic..."\n\
    cp -R /usr/src/mautic/* /var/www/html/\n\
    # Criar diretórios essenciais após a cópia\n\
    mkdir -p /var/www/html/media /var/www/html/app/config /var/www/html/app/cache /var/www/html/app/logs\n\
    # Garantir permissões corretas\n\
    chmod -R 777 /var/www/html\n\
else\n\
    echo "Arquivos do Mautic detectados, mantendo existentes."\n\
fi\n\
exec /usr/local/bin/docker-entrypoint.sh "$@"' > /usr/local/bin/startup.sh && chmod +x /usr/local/bin/startup.sh

# Configurar o novo ponto de entrada
ENTRYPOINT ["/usr/local/bin/startup.sh"]
CMD ["apache2-foreground"]