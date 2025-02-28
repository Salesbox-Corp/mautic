# Customizações do Mautic

Este documento detalha as customizações implementadas no Mautic para nossa solução multi-tenant.

## 1. Configuração Inicial Automática

### Local.php
O arquivo `local.php` é configurado automaticamente com:
- Conexão com banco de dados
- Chave secreta
- URL do site
- Configurações de email
- Flag para pular instalação

### Variáveis de Ambiente
Todas as configurações sensíveis são gerenciadas via variáveis de ambiente:
```bash
MAUTIC_DB_HOST=
MAUTIC_DB_PORT=
MAUTIC_DB_NAME=
MAUTIC_DB_USER=
MAUTIC_DB_PASSWORD=
MAUTIC_URL=
MAUTIC_SECRET_KEY=
```

## 2. Personalização de Logo

### Locais dos Logos
O logo personalizado é instalado em três locais:
1. `/var/www/html/app/assets/images/mautic_logo.png` - Logo principal
2. `/var/www/html/media/images/mautic_logo_db.png` - Logo do banco de dados
3. `/var/www/html/app/assets/images/themes/blank/mautic_logo.png` - Logo da tela de login

### Requisitos do Logo
- Formato: PNG recomendado
- Dimensões sugeridas: 200x50 pixels
- Local do arquivo: `assets/default_logo.png`

## 3. Processo de Deploy

### Build da Imagem
```bash
# Build
docker build -t mautic-${CLIENT}-${ENVIRONMENT}:${VERSION} .

# Push para ECR
aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/mautic-${CLIENT}-${ENVIRONMENT}:${VERSION}
```

### Atualização do ECS
```bash
aws ecs update-service \
  --cluster mautic-${CLIENT}-${ENVIRONMENT}-cluster \
  --service mautic-${CLIENT}-${ENVIRONMENT}-service \
  --force-new-deployment
```

## 4. Segurança

### Gerenciamento de Credenciais
- Todas as credenciais são armazenadas no AWS Secrets Manager
- Nenhuma informação sensível é armazenada nos arquivos ou imagens
- Permissões são gerenciadas via IAM roles

### Permissões de Arquivos
- Arquivos de configuração: 644
- Diretórios: 755
- Propriedade: www-data:www-data

## 5. Manutenção

### Atualizando Logos
1. Substituir o arquivo `assets/default_logo.png`
2. Executar novo build e deploy

### Atualizando Configurações
1. Atualizar variáveis de ambiente no ECS
2. Forçar novo deployment do serviço 