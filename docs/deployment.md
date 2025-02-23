# Processo de Deployment

## Fluxo Normal
1. Nova versão é criada da main
2. Testes automatizados são executados
3. Release branch é criada
4. Deploy para clientes de teste
5. Aprovação para produção
6. Deploy em produção

## Rollback
1. Identificação de problema
2. Execução do script de rollback
3. Notificação da equipe
4. Análise post-mortem

## Ambientes
- demo: Ambiente de demonstração
- staging: Homologação
- prod: Produção 