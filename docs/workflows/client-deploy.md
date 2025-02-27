# Workflow de Deploy de Clientes

Este workflow automatiza o processo de deploy de instâncias Mautic personalizadas para diferentes clientes em ambientes AWS.

## Índice
- [Visão Geral](#visão-geral)
- [Parâmetros de Entrada](#parâmetros-de-entrada)
- [Configuração do Cliente](#configuração-do-cliente)
- [Processo de Deploy](#processo-de-deploy)
- [Personalização da Logo](#personalização-da-logo)
- [Verificação do Deploy](#verificação-do-deploy)

## Visão Geral

O workflow `client-deploy.yml` é responsável por:
1. Preparar o ambiente de deploy
2. Gerenciar configurações específicas do cliente
3. Construir e publicar a imagem Docker
4. Realizar o deploy na infraestrutura AWS
5. Verificar o sucesso do deploy

## Parâmetros de Entrada

| Parâmetro | Obrigatório | Descrição | Valor Padrão |
|-----------|-------------|-----------|--------------|
| `client` | Sim | Nome do cliente para deploy | - |
| `environment` | Sim | Ambiente de deploy (demo/staging/prd) | demo |
| `version` | Sim | Versão para deploy | latest |
| `aws_region` | Sim | Região AWS para recursos | us-east-2 |
| `custom_logo_url` | Não | URL do logo personalizado | - |

## Configuração do Cliente

As configurações dos clientes são armazenadas no arquivo `clients/config.json` com a seguinte estrutura:

```json
{
  "clients": {
    "nome-do-cliente": {
      "logo_url": "https://url-do-logo.com/logo.png",
      "environments": {
        "demo": {},
        "staging": {},
        "prd": {}
      }
    }
  }
}
```

### Gerenciamento Automático

O workflow gerencia automaticamente o arquivo `config.json`:
- Cria o arquivo se não existir
- Adiciona novos clientes quando necessário
- Atualiza configurações existentes
- Mantém histórico de alterações através de commits

## Processo de Deploy

1. **Preparação**
   - Extração dos parâmetros de entrada
   - Validação do ambiente
   - Configuração das credenciais AWS

2. **Configuração**
   - Definição de variáveis de ambiente
   - Gerenciamento do arquivo de configuração do cliente
   - Configuração da logo personalizada

3. **Build e Deploy**
   - Build da imagem Docker
   - Push para Amazon ECR
   - Deploy no ECS

## Personalização da Logo

### Primeira Configuração
1. Forneça a URL do logo no parâmetro `custom_logo_url`
2. O workflow salvará a URL no `config.json`
3. A logo será configurada automaticamente no Mautic

### Deploys Subsequentes
- A logo será configurada automaticamente usando a URL salva
- Não é necessário fornecer a URL novamente
- Para alterar a logo, basta fornecer uma nova URL no parâmetro `custom_logo_url`

### Funcionamento
- A logo é baixada durante a inicialização do container
- Armazenada em `/var/www/html/media/images/custom_logo.png`
- Configurada no Mautic através do arquivo `local.php`

## Verificação do Deploy

O workflow verifica automaticamente:
1. Status do serviço ECS
2. Disponibilidade do Load Balancer
3. Acessibilidade da aplicação

### URLs de Acesso
- A URL da aplicação é gerada automaticamente no formato:
  `http://mautic-{cliente}-{ambiente}-alb.{região}.elb.amazonaws.com`

## Exemplos de Uso

### Deploy Básico
```bash
# Via GitHub Actions UI
Cliente: cliente-exemplo
Ambiente: demo
Versão: latest
Região: us-east-2
```

### Deploy com Logo Personalizada
```bash
# Via GitHub Actions UI
Cliente: cliente-exemplo
Ambiente: demo
Versão: latest
Região: us-east-2
URL do Logo: https://exemplo.com/logo.png
```

## Troubleshooting

### Erros Comuns

1. **Erro de Permissão Git**
   - Mensagem: "nothing to commit, working tree clean"
   - Causa: Tentativa de commit sem alterações
   - Solução: Normal quando não há mudanças na configuração

2. **Erro de Deploy ECS**
   - Mensagem: "Serviço ECS não está ativo"
   - Causa: Problemas na infraestrutura ou configuração
   - Solução: Verificar logs do ECS e configurações do serviço 