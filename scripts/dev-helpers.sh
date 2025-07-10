#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${CYAN}🛠️  LocalStack - Ferramentas de Desenvolvimento${NC}"
echo "=================================================="

# Carregando variáveis de ambiente
if [ -f .env-dev ]; then
    source .env-dev
else
    echo -e "${RED}❌ Arquivo .env-dev não encontrado${NC}"
    exit 1
fi

# Verificar se LocalStack está rodando
if ! docker ps | grep -q localstack-main; then
    echo -e "${RED}❌ LocalStack não está rodando${NC}"
    echo -e "${YELLOW}💡 Execute: ./start.sh${NC}"
    exit 1
fi

# Função para mostrar menu
show_menu() {
    echo -e "\n${BLUE}📋 Menu de Opções:${NC}"
    echo "1. 📤 Enviar mensagem de teste para SNS"
    echo "2. 📋 Listar mensagens nas filas SQS"
    echo "3. 📦 Listar arquivos nos buckets S3"
    echo "4. 🔍 Visualizar mensagens SQS em tempo real"
    echo "5. 🧹 Limpar todas as filas SQS"
    echo "6. 📊 Status rápido dos serviços"
    echo "7. 🔐 Visualizar secrets"
    echo "8. 🚪 Sair"
    echo -n -e "${CYAN}Escolha uma opção (1-8): ${NC}"
}

# Função para enviar mensagem de teste
send_test_message() {
    echo -e "\n${BLUE}📤 Enviar Mensagem de Teste${NC}"
    echo "Tópicos disponíveis:"
    echo "1. input-topic (simula entrada)"
    echo "2. output-topic (simula saída de processamento)"
    echo -n "Escolha o tópico (1-2): "
    read topic_choice
    
    case $topic_choice in
        1)
            topic_name="input-topic"
            message="Mensagem de teste de entrada - $(date)"
            ;;
        2)
            topic_name="output-topic"
            message="Mensagem de teste de saída - $(date)"
            ;;
        *)
            echo -e "${RED}❌ Opção inválida${NC}"
            return 1
            ;;
    esac
    
    echo -n "Mensagem personalizada? (deixe vazio para usar padrão): "
    read custom_message
    
    if [ -n "$custom_message" ]; then
        message="$custom_message"
    fi
    
    topic_arn=$(aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL --query "Topics[?contains(TopicArn, '$topic_name')].TopicArn" --output text)
    
    if [ -n "$topic_arn" ]; then
        message_id=$(aws sns publish --topic-arn "$topic_arn" --message "$message" --endpoint-url=$AWS_ENDPOINT_URL --query 'MessageId' --output text)
        echo -e "${GREEN}✅ Mensagem enviada com sucesso!${NC}"
        echo -e "${BLUE}📋 ID da mensagem: $message_id${NC}"
        echo -e "${BLUE}📋 Tópico: $topic_name${NC}"
    else
        echo -e "${RED}❌ Tópico não encontrado${NC}"
    fi
}

# Função para listar mensagens SQS
list_sqs_messages() {
    echo -e "\n${BLUE}📋 Mensagens nas Filas SQS${NC}"
    
    queues=("input-queue" "output-queue")
    
    for queue in "${queues[@]}"; do
        echo -e "\n${PURPLE}📋 Fila: $queue${NC}"
        queue_url="http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/$queue"
        
        # Verificar se há mensagens
        messages=$(aws sqs receive-message --queue-url "$queue_url" --endpoint-url=$AWS_ENDPOINT_URL --max-number-of-messages 10 2>/dev/null)
        
        if echo "$messages" | grep -q "Messages"; then
            count=$(echo "$messages" | jq '.Messages | length' 2>/dev/null || echo "N/A")
            echo -e "${GREEN}✅ $count mensagem(ns) encontrada(s)${NC}"
            
            # Mostrar preview das mensagens
            echo "$messages" | jq -r '.Messages[] | "📩 ID: " + .MessageId + "\n📝 Resumo: " + (.Body | fromjson | .Message // .Body)[0:100] + "..."' 2>/dev/null || echo "📝 Mensagens encontradas mas não foi possível parsear"
        else
            echo -e "${YELLOW}⚠️  Nenhuma mensagem na fila${NC}"
        fi
    done
}

# Função para listar arquivos S3
list_s3_files() {
    echo -e "\n${BLUE}📦 Arquivos nos Buckets S3${NC}"
    
    buckets=("input-bucket" "output-bucket")
    
    for bucket in "${buckets[@]}"; do
        echo -e "\n${PURPLE}📦 Bucket: $bucket${NC}"
        
        files=$(aws s3 ls s3://$bucket/ --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null)
        
        if [ -n "$files" ]; then
            echo -e "${GREEN}✅ Arquivos encontrados:${NC}"
            echo "$files" | while read -r line; do
                echo -e "${BLUE}📄 $line${NC}"
            done
        else
            echo -e "${YELLOW}⚠️  Bucket vazio${NC}"
        fi
    done
}

# Função para visualizar mensagens em tempo real
watch_sqs_messages() {
    echo -e "\n${BLUE}🔍 Monitoramento SQS em Tempo Real${NC}"
    echo "Pressione Ctrl+C para parar"
    
    while true; do
        clear
        echo -e "${CYAN}🔍 Monitoramento SQS - $(date)${NC}"
        echo "=================================="
        
        queues=("input-queue" "output-queue")
        
        for queue in "${queues[@]}"; do
            echo -e "\n${PURPLE}📋 $queue${NC}"
            queue_url="http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/$queue"
            
            # Pegar até 3 mensagens
            messages=$(aws sqs receive-message --queue-url "$queue_url" --endpoint-url=$AWS_ENDPOINT_URL --max-number-of-messages 3 2>/dev/null)
            
            if echo "$messages" | grep -q "Messages"; then
                echo "$messages" | jq -r '.Messages[] | "🕒 " + (.Body | fromjson | .Timestamp // "N/A") + "\n📝 " + (.Body | fromjson | .Message // .Body)[0:80] + "...\n"' 2>/dev/null || echo "📝 Mensagens encontradas"
            else
                echo -e "${YELLOW}⚠️  Nenhuma mensagem${NC}"
            fi
        done
        
        sleep 5
    done
}

# Função para limpar filas
clear_queues() {
    echo -e "\n${BLUE}🧹 Limpando Filas SQS${NC}"
    
    echo -e "${YELLOW}⚠️  Isso removerá todas as mensagens das filas${NC}"
    echo -n "Continuar? (s/N): "
    read confirm
    
    if [[ $confirm =~ ^[Ss]$ ]]; then
        queues=("input-queue" "output-queue")
        
        for queue in "${queues[@]}"; do
            echo -n "🧹 Limpando $queue... "
            queue_url="http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/$queue"
            
            if aws sqs purge-queue --queue-url "$queue_url" --endpoint-url=$AWS_ENDPOINT_URL &>/dev/null; then
                echo -e "${GREEN}✅ Limpa${NC}"
            else
                echo -e "${RED}❌ Erro${NC}"
            fi
        done
    else
        echo -e "${BLUE}ℹ️  Operação cancelada${NC}"
    fi
}

# Função para status rápido
quick_status() {
    echo -e "\n${BLUE}📊 Status Rápido dos Serviços${NC}"
    
    # S3
    echo -n "📦 S3 Buckets: "
    bucket_count=$(aws s3 ls --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null | wc -l)
    echo -e "${GREEN}$bucket_count buckets${NC}"
    
    # SNS
    echo -n "📢 SNS Topics: "
    topic_count=$(aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL --query 'Topics' --output text 2>/dev/null | wc -l)
    echo -e "${GREEN}$topic_count topics${NC}"
    
    # SQS
    echo -n "📋 SQS Queues: "
    queue_count=$(aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL --query 'QueueUrls' --output text 2>/dev/null | wc -w)
    echo -e "${GREEN}$queue_count queues${NC}"
    
    # Secrets
    echo -n "🔐 Secrets: "
    secret_count=$(aws secretsmanager list-secrets --endpoint-url=$AWS_ENDPOINT_URL --query 'SecretList' --output text 2>/dev/null | wc -l)
    echo -e "${GREEN}$secret_count secrets${NC}"
}

# Função para visualizar secrets
view_secrets() {
    echo -e "\n${BLUE}🔐 Secrets Manager${NC}"
    
    secrets=$(aws secretsmanager list-secrets --endpoint-url=$AWS_ENDPOINT_URL --query 'SecretList[].Name' --output text 2>/dev/null)
    
    if [ -n "$secrets" ]; then
        echo -e "${GREEN}✅ Secrets encontrados:${NC}"
        for secret in $secrets; do
            echo -e "\n${PURPLE}🔑 $secret${NC}"
            value=$(aws secretsmanager get-secret-value --secret-id "$secret" --endpoint-url=$AWS_ENDPOINT_URL --query 'SecretString' --output text 2>/dev/null)
            echo -e "${BLUE}📝 Valor: $value${NC}"
        done
    else
        echo -e "${YELLOW}⚠️  Nenhum secret encontrado${NC}"
    fi
}

# Loop principal
while true; do
    show_menu
    read choice
    
    case $choice in
        1) send_test_message ;;
        2) list_sqs_messages ;;
        3) list_s3_files ;;
        4) watch_sqs_messages ;;
        5) clear_queues ;;
        6) quick_status ;;
        7) view_secrets ;;
        8) 
            echo -e "${GREEN}👋 Até logo!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opção inválida. Tente novamente.${NC}"
            ;;
    esac
    
    echo -e "\n${BLUE}Pressione Enter para continuar...${NC}"
    read
done