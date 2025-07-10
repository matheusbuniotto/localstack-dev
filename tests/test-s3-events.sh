#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Teste: S3 Events → SNS → SQS${NC}"
echo "=============================================="

# Carregando variáveis de ambiente
source .env-dev

# Função para verificar se mensagem chegou na fila
check_queue_message() {
    local queue_url=$1
    local expected_pattern=$2
    local timeout=10
    local count=0
    
    echo -n "Aguardando mensagem na fila... "
    
    while [ $count -lt $timeout ]; do
        # Verificar se há mensagens na fila
        message=$(aws sqs receive-message --queue-url "$queue_url" --endpoint-url=$AWS_ENDPOINT_URL --max-number-of-messages 1 2>/dev/null)
        
        if echo "$message" | grep -q "Messages"; then
            if [ -n "$expected_pattern" ]; then
                if echo "$message" | grep -q "$expected_pattern"; then
                    echo -e "${GREEN}✅ Mensagem encontrada com padrão esperado${NC}"
                    return 0
                fi
            else
                echo -e "${GREEN}✅ Mensagem encontrada${NC}"
                return 0
            fi
        fi
        
        sleep 1
        count=$((count + 1))
        echo -n "."
    done
    
    echo -e "${RED}❌ Timeout - Mensagem não encontrada${NC}"
    return 1
}

# Limpar mensagens antigas da fila
echo "🧹 Limpando mensagens antigas da fila..."
aws sqs purge-queue --queue-url "http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/input-queue" --endpoint-url=$AWS_ENDPOINT_URL &>/dev/null

# Criar arquivo de teste
test_file="/tmp/test-s3-events-$(date +%s).txt"
echo "Arquivo de teste para S3 Events - $(date)" > "$test_file"

echo "📄 Criando arquivo de teste: $(basename $test_file)"

# Upload para S3
echo "📤 Fazendo upload para S3..."
if aws s3 cp "$test_file" "s3://$S3_INPUT_BUCKET/$(basename $test_file)" --endpoint-url=$AWS_ENDPOINT_URL; then
    echo -e "${GREEN}✅ Upload realizado com sucesso${NC}"
else
    echo -e "${RED}❌ Falha no upload${NC}"
    exit 1
fi

# Verificar se a mensagem chegou na fila SQS
echo "🔍 Verificando se evento chegou na fila SQS..."
if check_queue_message "http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/input-queue" "ObjectCreated"; then
    echo -e "${GREEN}🎉 Teste S3 Events passou!${NC}"
    echo "✅ Fluxo: S3 Upload → SNS → SQS funcionando corretamente"
else
    echo -e "${RED}❌ Teste S3 Events falhou${NC}"
    echo "❌ Fluxo: S3 Upload → SNS → SQS não está funcionando"
    exit 1
fi

# Limpeza
rm -f "$test_file"

echo -e "${BLUE}📊 Teste S3 Events concluído com sucesso!${NC}"