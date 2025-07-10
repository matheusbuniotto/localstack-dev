#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Teste: SNS → SQS (Output Flow)${NC}"
echo "========================================"

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
                    # Mostrar parte da mensagem para debug
                    echo "📩 Conteúdo da mensagem:"
                    echo "$message" | jq -r '.Messages[0].Body' | jq -r '.Message' | head -c 100
                    echo "..."
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

# Obter ARN do tópico output
OUTPUT_TOPIC_ARN=$(aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL --query 'Topics[?contains(TopicArn, `output-topic`)].TopicArn' --output text)

echo "📋 Tópico de saída: $OUTPUT_TOPIC_ARN"

# Limpar mensagens antigas da fila
echo "🧹 Limpando mensagens antigas da fila de saída..."
aws sqs purge-queue --queue-url "http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/output-queue" --endpoint-url=$AWS_ENDPOINT_URL &>/dev/null

# Criar mensagem de teste
test_message="Mensagem de teste do processamento Lambda - $(date)"
echo "📝 Criando mensagem de teste"

# Publicar mensagem no SNS
echo "📤 Publicando mensagem no SNS output-topic..."
message_id=$(aws sns publish --topic-arn "$OUTPUT_TOPIC_ARN" --message "$test_message" --endpoint-url=$AWS_ENDPOINT_URL --query 'MessageId' --output text)

if [ -n "$message_id" ]; then
    echo -e "${GREEN}✅ Mensagem publicada com sucesso (ID: $message_id)${NC}"
else
    echo -e "${RED}❌ Falha ao publicar mensagem${NC}"
    exit 1
fi

# Verificar se a mensagem chegou na fila SQS
echo "🔍 Verificando se mensagem chegou na fila SQS de saída..."
if check_queue_message "http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/output-queue" "processamento"; then
    echo -e "${GREEN}🎉 Teste SNS-SQS passou!${NC}"
    echo "✅ Fluxo: SNS (output-topic) → SQS (output-queue) funcionando corretamente"
else
    echo -e "${RED}❌ Teste SNS-SQS falhou${NC}"
    echo "❌ Fluxo: SNS (output-topic) → SQS (output-queue) não está funcionando"
    exit 1
fi

echo -e "${BLUE}📊 Teste SNS-SQS concluído com sucesso!${NC}"