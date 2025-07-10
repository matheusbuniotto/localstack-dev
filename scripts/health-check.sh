#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔍 Health Check - LocalStack Environment${NC}"
echo "================================================="

# Carregando variáveis de ambiente
if [ -f .env-dev ]; then
    source .env-dev
else
    echo -e "${RED}❌ Arquivo .env-dev não encontrado${NC}"
    exit 1
fi

# Verificar se as variáveis foram carregadas
if [ -z "$AWS_ENDPOINT_URL" ]; then
    echo -e "${RED}❌ Variáveis de ambiente não carregadas corretamente${NC}"
    exit 1
fi

# Função para verificar status
check_service() {
    local service_name=$1
    local check_command=$2
    
    echo -n "Verificando $service_name... "
    if eval "$check_command" &> /dev/null; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FALHOU${NC}"
        return 1
    fi
}

# Função para verificar com detalhes
check_service_detailed() {
    local service_name=$1
    local check_command=$2
    local expected_count=$3
    
    echo -n "Verificando $service_name... "
    result=$(eval "$check_command" 2>/dev/null)
    if [ $? -eq 0 ]; then
        if [ -n "$expected_count" ]; then
            count=$(echo "$result" | wc -l)
            if [ "$count" -ge "$expected_count" ]; then
                echo -e "${GREEN}✅ OK ($count encontrados)${NC}"
                return 0
            else
                echo -e "${YELLOW}⚠️  PARCIAL ($count/$expected_count)${NC}"
                return 1
            fi
        else
            echo -e "${GREEN}✅ OK${NC}"
            return 0
        fi
    else
        echo -e "${RED}❌ FALHOU${NC}"
        return 1
    fi
}

# Contador de falhas
failures=0

# 1. Verificar se LocalStack está rodando
echo -e "\n${BLUE}🐳 Container Status${NC}"
if ! check_service "LocalStack Container" "docker ps | grep localstack-main"; then
    ((failures++))
    echo -e "${RED}❌ LocalStack não está rodando. Execute: ./start.sh${NC}"
    exit 1
fi

# 2. Verificar conectividade com LocalStack
echo -e "\n${BLUE}🌐 Conectividade${NC}"
if ! check_service "LocalStack Health Endpoint" "curl -sf http://localhost:4566/_localstack/health"; then
    ((failures++))
fi

# 3. Verificar serviços AWS
echo -e "\n${BLUE}☁️  Serviços AWS${NC}"

# S3
if ! check_service_detailed "S3 Buckets" "aws s3 ls --endpoint-url=$AWS_ENDPOINT_URL | grep -E '(input-bucket|output-bucket)'" 2; then
    ((failures++))
fi

# SNS
if ! check_service_detailed "SNS Topics" "aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL --query 'Topics[*].TopicArn' --output text | tr '\t' '\n' | grep -E '(input-topic|output-topic)'" 2; then
    ((failures++))
fi

# SQS
if ! check_service_detailed "SQS Queues" "aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL --query 'QueueUrls[*]' --output text | tr '\t' '\n' | grep -E '(input-queue|output-queue)'" 2; then
    ((failures++))
fi

# Secrets Manager
if ! check_service "Secrets Manager" "aws secretsmanager list-secrets --endpoint-url=$AWS_ENDPOINT_URL --query 'SecretList[0].Name' --output text | grep api-keys"; then
    ((failures++))
fi

# 4. Verificar configurações de eventos
echo -e "\n${BLUE}🔗 Configurações de Eventos${NC}"

# S3 Event Notifications
if ! check_service "S3 Event Notifications" "aws s3api get-bucket-notification-configuration --bucket input-bucket --endpoint-url=$AWS_ENDPOINT_URL | grep TopicArn"; then
    ((failures++))
fi

# SNS Subscriptions
input_topic_arn=$(aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL --query 'Topics[?contains(TopicArn, `input-topic`)].TopicArn' --output text)
output_topic_arn=$(aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL --query 'Topics[?contains(TopicArn, `output-topic`)].TopicArn' --output text)

if ! check_service "SNS Input Subscriptions" "aws sns list-subscriptions-by-topic --topic-arn $input_topic_arn --endpoint-url=$AWS_ENDPOINT_URL | grep SubscriptionArn"; then
    ((failures++))
fi

if ! check_service "SNS Output Subscriptions" "aws sns list-subscriptions-by-topic --topic-arn $output_topic_arn --endpoint-url=$AWS_ENDPOINT_URL | grep SubscriptionArn"; then
    ((failures++))
fi

# 5. Resumo final
echo -e "\n${BLUE}📊 Resumo do Health Check${NC}"
echo "================================================="

if [ $failures -eq 0 ]; then
    echo -e "${GREEN}🎉 Todos os serviços estão funcionando perfeitamente!${NC}"
    echo -e "${GREEN}✅ Ambiente pronto para desenvolvimento${NC}"
    exit 0
else
    echo -e "${RED}❌ $failures verificação(ões) falharam${NC}"
    echo -e "${YELLOW}⚠️  Execute ./start.sh para corrigir problemas${NC}"
    exit 1
fi