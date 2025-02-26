# Processo de Deployment

## Pré-requisitos
- Infraestrutura do cliente já configurada (via workflow `setup-client`)
- Credenciais AWS configuradas
- Código do Mautic pronto para deploy

## Métodos de Deployment

### Usando GitHub Actions (Recomendado)

1. Acesse a aba "Actions" no repositório GitHub
2. Selecione o workflow "Client Deployment"
3. Clique em "Run workflow"
4. Preencha os campos:
   - **Cliente**: Nome do cliente (deve corresponder ao usado na configuração da infraestrutura)
   - **Ambiente**: Ambiente de destino (demo/staging/prd)
   - **Versão**: Tag da versão a ser deployada (default: latest)
   - **AWS Region**: Região onde a infraestrutura foi criada

5. Clique em "Run workflow" para iniciar o processo de deployment

O workflow irá:
1. Construir a imagem Docker do Mautic
2. Enviar a imagem para o repositório ECR do cliente
3. Atualizar o serviço ECS para usar a nova imagem
4. Verificar se o deployment foi bem-sucedido
5. Exibir a URL de acesso ao Mautic

### Usando a Linha de Comando

Para fazer o deployment manualmente via linha de comando:

```bash
# Formato básico
./scripts/deploy-client.sh <client_name> <environment> [version] [aws_region]

# Exemplo
./scripts/deploy-client.sh salesbox prd latest us-west-2
```

## Verificação do Deployment

Após o deployment, você pode verificar o status do serviço ECS:

```bash
# Verificar status do serviço
aws ecs describe-services \
  --cluster mautic-<client>-<environment>-cluster \
  --services mautic-<client>-<environment>-service \
  --region <aws_region>

# Obter URL do load balancer
aws elbv2 describe-load-balancers \
  --names mautic-<client>-<environment>-alb \
  --region <aws_region> \
  --query 'LoadBalancers[0].DNSName' \
  --output text
```

## Rollback

Em caso de problemas com o deployment, você pode fazer rollback para uma versão anterior:

1. Acesse a aba "Actions" no repositório GitHub
2. Selecione o workflow "Client Rollback"
3. Clique em "Run workflow"
4. Preencha os campos com as mesmas informações do deployment, mas especificando a versão anterior

Ou via linha de comando:

```bash
# Obter lista de imagens disponíveis
aws ecr describe-images \
  --repository-name mautic-<client>-<environment> \
  --region <aws_region>

# Atualizar serviço para usar uma versão específica
aws ecs update-service \
  --cluster mautic-<client>-<environment>-cluster \
  --service mautic-<client>-<environment>-service \
  --force-new-deployment \
  --region <aws_region>
```

## Ambientes
- demo: Ambiente de demonstração
- staging: Homologação
- prod: Produção 