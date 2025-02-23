# Processo de Inicialização de Novo Cliente

## Pré-requisitos
- AWS credentials configuradas
- Terraform instalado
- Cliente aprovado comercialmente

## Passos
1. Executar script de inicialização:
   ```bash
   ./scripts/init-client.sh <client_name> <environment>
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