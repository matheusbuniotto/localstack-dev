# LocalStack - Ambiente de Desenvolvimento Local

Este projeto configura um ambiente de desenvolvimento local usando LocalStack para simular serviços AWS com a arquitetura descrita abaixo:

## Arquitetura

```
Upload de Arquivo → S3 (input-bucket) → SNS (input-topic) → SQS (input-queue) → [Processamento Lambda] → SNS (output-topic) & S3 (output-bucket) → SQS (output-queue)
```

## Serviços Configurados

- **S3**: `input-bucket`, `output-bucket`
- **SNS**: `input-topic`, `output-topic`
- **SQS**: `input-queue`, `output-queue`
- **Secrets Manager**: `api-keys`

## Pré-requisitos

- Docker
- Docker Compose
- AWS CLI

## Início Rápido

### 1. Clonar o repositório
```bash
git clone matheusbuniotto/localstack-dev
cd localstack-dev
```

### 2. Iniciar o ambiente
```bash
./start.sh
```

Este script irá:
- Iniciar o container LocalStack
- Criar todos os recursos AWS (S3, SNS, SQS, Secrets Manager)
- Configurar as notificações de eventos
- Configurar as assinaturas SNS → SQS

### 3. Verificar se está funcionando
```bash
# Testar upload para S3 (isso deve disparar o fluxo completo)
echo "Arquivo de teste" > test.txt
aws s3 cp test.txt s3://input-bucket/ --endpoint-url=http://localhost:4566

# Verificar se a mensagem chegou na fila de entrada
aws sqs receive-message --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/input-queue --endpoint-url=http://localhost:4566
```

## Configuração Manual

Se preferir executar os passos manualmente:

### 1. Iniciar LocalStack
```bash
docker compose up -d
```

### 2. Configurar infraestrutura
```bash
./scripts/setup-infrastructure.sh
```

### 3. Configurar eventos
```bash
./scripts/configure-events.sh
```

## Variáveis de Ambiente

As configurações estão no arquivo `.env-dev`:
- `AWS_ENDPOINT_URL`: http://localhost:4566
- `AWS_ACCESS_KEY_ID`: test
- `AWS_SECRET_ACCESS_KEY`: test
- Nomes dos recursos AWS

## Comandos Úteis

### Verificar status dos serviços
```bash
curl http://localhost:4566/_localstack/health
```

### Listar recursos
```bash
# S3 buckets
aws s3 ls --endpoint-url=http://localhost:4566

# SNS topics
aws sns list-topics --endpoint-url=http://localhost:4566

# SQS queues
aws sqs list-queues --endpoint-url=http://localhost:4566

# Secrets
aws secretsmanager list-secrets --endpoint-url=http://localhost:4566
```

### Testar fluxo completo
```bash
# 1. Upload para S3
aws s3 cp arquivo.txt s3://input-bucket/ --endpoint-url=http://localhost:4566

# 2. Verificar mensagem na fila de entrada
aws sqs receive-message --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/input-queue --endpoint-url=http://localhost:4566

# 3. Simular processamento - publicar na saída
aws sns publish --topic-arn arn:aws:sns:us-east-1:000000000000:output-topic --message "Processamento concluído" --endpoint-url=http://localhost:4566

# 4. Verificar mensagem na fila de saída
aws sqs receive-message --queue-url http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/output-queue --endpoint-url=http://localhost:4566
```

## Parar o Ambiente

```bash
docker compose down
```

## Estrutura do Projeto

```
localstack-dev/
├── docker-compose.yml      # Configuração do LocalStack
├── start.sh               # Script de inicialização
├── .env-dev              # Variáveis de ambiente
├── scripts/
│   ├── setup-infrastructure.sh  # Criação dos recursos AWS
│   └── configure-events.sh     # Configuração dos eventos
└── README.md             # Este arquivo
```

## Próximos Passos

- Integração com código Lambda (repositório separado)
- Testes automatizados do fluxo completo