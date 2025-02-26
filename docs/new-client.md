# Processo de Inicialização de Novo Cliente

## Pré-requisitos
- AWS credentials configuradas
- Terraform instalado
- Cliente aprovado comercialmente

## Passos

### Usando a Interface GitHub Actions

1. Acesse a aba "Actions" no repositório GitHub
2. Selecione o workflow "Setup New Client"
3. Clique em "Run workflow"
4. Preencha os campos:
   - **AWS Region**: Região onde os recursos serão criados
   - **Client**: Nome do cliente (sem espaços ou caracteres especiais)
   - **Environment**: Ambiente (demo, staging, prd)
   - **Clean Resources**: Marque esta opção para limpar recursos existentes antes de criar novos

### Usando a Linha de Comando

1. Executar script de inicialização:
   ```bash
   # Formato básico
   ./scripts/setup-client.sh <client_name> <environment> [aws_region] [clean_resources]
   
   # Exemplo sem limpeza de recursos
   ./scripts/setup-client.sh salesbox prd us-west-2
   
   # Exemplo com limpeza de recursos existentes
   ./scripts/setup-client.sh salesbox prd us-west-2 true
   ```

2. Verificar recursos criados:
   - VPC e networking
   - RDS Database
   - ECS Cluster
   - Load Balancer
   - Security Groups

3. Configurar DNS e certificados

4. Realizar deploy inicial da aplicação

5. Validar ambiente

## Gerenciamento de Recursos Existentes

O sistema agora oferece duas abordagens para lidar com recursos existentes:

1. **Detecção e Reutilização**: Por padrão, o sistema detecta recursos existentes (ECR, banco de dados, etc.) e os reutiliza.

2. **Limpeza e Recriação**: Ativando a opção "Clean Resources", o sistema remove todos os recursos existentes antes de criar novos.

### Recursos Gerenciados
- Repositório ECR
- Banco de dados e usuário
- Cluster ECS e serviços
- Load Balancer, listeners e target groups
- Secrets e parâmetros SSM 