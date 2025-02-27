# Configuração de Clientes

Este documento descreve como gerenciar as configurações dos clientes no sistema multi-tenant do Mautic.

## Estrutura de Configuração

### Arquivo config.json

O arquivo `clients/config.json` é o ponto central de configuração dos clientes. Ele mantém todas as configurações específicas de cada cliente, incluindo:

- URLs de logos personalizados
- Configurações de ambiente
- Outras personalizações futuras

Exemplo de estrutura:
```json
{
  "clients": {
    "cliente1": {
      "name": "Cliente Um",
      "logo_url": "https://cliente1.com/logo.png",
      "environments": {
        "demo": {},
        "staging": {},
        "prd": {}
      }
    }
  }
}
```

## Gerenciamento de Clientes

### Adicionando um Novo Cliente

1. **Via Script**
   ```bash
   ./scripts/add-client.sh cliente-exemplo "Nome do Cliente" https://exemplo.com/logo.png
   ```

2. **Via Deploy**
   - Execute o workflow de deploy
   - Forneça a URL do logo no campo `custom_logo_url`
   - O cliente será adicionado automaticamente

### Atualizando Configurações

1. **Alterando o Logo**
   - Execute um novo deploy
   - Forneça a nova URL no campo `custom_logo_url`
   - O sistema atualizará automaticamente

2. **Editando Manualmente**
   - Edite o arquivo `clients/config.json`
   - Faça commit das alterações
   - Execute um novo deploy

## Personalização da Logo

### Requisitos da Imagem
- Formatos suportados: PNG, JPG, GIF
- Tamanho recomendado: 200x50 pixels
- Fundo transparente (recomendado)

### Processo de Atualização
1. A imagem é baixada durante a inicialização
2. Armazenada em `/var/www/html/media/images/`
3. Configurada no Mautic via `local.php`

## Ambientes

Cada cliente pode ter múltiplos ambientes:

- **demo**: Ambiente de demonstração/testes
- **staging**: Ambiente de homologação
- **prd**: Ambiente de produção

### Configurações por Ambiente

Cada ambiente é isolado e possui:
- Banco de dados próprio
- Configurações específicas
- URL única
- Recursos AWS dedicados

## Boas Práticas

1. **Nomenclatura**
   - Use nomes em minúsculos
   - Evite caracteres especiais
   - Use hífen para separar palavras

2. **Logos**
   - Use URLs permanentes
   - Prefira CDNs ou storages dedicados
   - Faça backup das imagens

3. **Versionamento**
   - Mantenha o `config.json` versionado
   - Documente alterações nos commits
   - Faça backup regular

## Troubleshooting

### Problemas Comuns

1. **Logo não aparece**
   - Verifique se a URL está acessível
   - Confirme as permissões do diretório
   - Verifique os logs do container

2. **Erro no config.json**
   - Valide a sintaxe JSON
   - Verifique a estrutura do arquivo
   - Confirme as permissões

## Segurança

### Boas Práticas
- Não armazene senhas no `config.json`
- Use HTTPS para URLs de logos
- Mantenha backups seguros
- Limite o acesso ao repositório

### Permissões
- Arquivos: 644
- Diretórios: 755
- Proprietário: www-data 