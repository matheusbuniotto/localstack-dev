#!/bin/bash

echo "🚀 Iniciando Ambiente de Desenvolvimento LocalStack..."

# Carregando variáveis de ambiente
source .env-dev

# Start  LocalStack
echo "📦 Iniciando container do LocalStack..."
docker compose up -d

# Sonequinha do localstack
echo "⏳ Aguardando o LocalStack ficar pronto..."
sleep 10

# Setup  de infra
echo "🔧 Configurando infraestrutura AWS..."
./scripts/setup-infrastructure.sh

# Configurando cadeia dos eventos 
echo "🔗 Configurando arquitetura orientada a eventos..."
./scripts/configure-events.sh

echo "✅ Ambiente de desenvolvimento LocalStack está pronto!"
echo ""
echo "📋 Serviços disponíveis:"
echo "  • Buckets S3: input-bucket, output-bucket"
echo "  • Tópicos SNS: input-topic, output-topic"
echo "  • Filas SQS: input-queue, output-queue"
echo "  • Secrets Manager: api-keys"
echo ""
echo "🌐 Endpoint do LocalStack: http://localhost:4566"
echo "📄 Variáveis de ambiente carregadas de .env-dev"
echo ""
echo "🧪 Para testar o fluxo de dados:"
echo "  aws s3 cp arquivo.txt s3://input-bucket/ --endpoint-url=http://localhost:4566"