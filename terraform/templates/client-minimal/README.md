# Setup de Cliente Mautic

Este documento descreve o processo de configuração de um novo cliente Mautic usando Terraform.

## Pré-requisitos

- AWS CLI configurado
- Terraform instalado
- Acesso à conta AWS com permissões necessárias

## Estrutura de Arquivos

```
terraform/templates/client-minimal/
├── main.tf           # Configuração principal
├── variables.tf      # Definição das variáveis
├── terraform.tfvars  # Valores das variáveis (você deve criar)
└── README.md         # Este arquivo
```

## Configuração

1. Crie um arquivo `terraform.tfvars` com as seguintes variáveis obrigatórias:

```hcl
client      = "nome-do-cliente"    # Nome do cliente (apenas letras minúsculas e hífens)
environment = "prd"                # Ambiente (demo/staging/prd)
project     = "mautic"            # Nome do projeto (padrão: mautic)
aws_region  = "us-east-1"         # Região AWS

# Configurações do Banco de Dados
db_host     = "endpoint-do-rds"   # Endpoint do RDS compartilhado
db_name     = "nome_do_banco"     # Nome do banco de dados do cliente
db_username = "usuario_do_banco"  # Usuário do banco de dados do cliente

# Recursos Computacionais (opcional)
task_cpu    = 1024               # CPU para o container (em unidades - padrão: 1024)
task_memory = 2048               # Memória para o container (em MB - padrão: 2048)

# Customização (opcional)
custom_logo_url = "https://exemplo.com/logo.png"  # URL do logo personalizado
```

2. Configurações Opcionais:

- **Logo Personalizado**: 
  - Forneça uma URL pública para a imagem do logo
  - Formatos recomendados: PNG ou JPG
  - Dimensões recomendadas: 200x50 pixels
  - Se não fornecido, será usado o logo padrão do Mautic

- **Recursos Computacionais**:
  - `task_cpu`: Unidades de CPU (1024 = 1 vCPU)
  - `task_memory`: Memória em MB
  - Valores padrão são adequados para a maioria dos casos

## Execução

1. Inicialize o Terraform:
```bash
terraform init
```

2. Verifique o plano de execução:
```bash
terraform plan
```

3. Aplique as configurações:
```bash
terraform apply
```

## Pós-instalação

Após a conclusão do deploy, você terá:
- Uma instância Mautic rodando em container ECS
- Banco de dados configurado
- Load Balancer configurado
- Logo personalizado (se configurado)

O URL de acesso será fornecido nos outputs do Terraform.

## Variáveis de Ambiente

| Variável | Descrição | Obrigatório | Padrão |
|----------|-----------|-------------|---------|
| client | Nome do cliente | Sim | - |
| environment | Ambiente de deploy | Sim | - |
| project | Nome do projeto | Sim | "mautic" |
| aws_region | Região AWS | Sim | - |
| db_host | Host do banco de dados | Sim | - |
| db_name | Nome do banco de dados | Sim | - |
| db_username | Usuário do banco | Sim | - |
| task_cpu | CPU para o container | Não | 1024 |
| task_memory | Memória para o container | Não | 2048 |
| custom_logo_url | URL do logo personalizado | Não | "" |

## Troubleshooting

1. **Erro de conexão com banco**: 
   - Verifique se o host do banco está correto
   - Confirme se as credenciais estão configuradas no AWS Secrets Manager

2. **Erro no deploy do container**:
   - Verifique os logs no CloudWatch
   - Confirme se a URL do logo (se fornecida) está acessível

## Suporte

Para problemas ou dúvidas, abra uma issue no repositório ou contate o time de DevOps. 