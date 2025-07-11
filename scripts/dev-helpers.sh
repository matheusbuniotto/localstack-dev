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
    echo "4. 📄 Enviar arquivo de teste para S3"
    echo "5. 🔍 Visualizar mensagens SQS em tempo real"
    echo "6. 🧹 Limpar todas as filas SQS"
    echo "7. 📊 Status rápido dos serviços"
    echo "8. 🔐 Visualizar secrets"
    echo "9. ➕ Adicionar nova secret"
    echo "10. 🚪 Sair"
    echo -n -e "${CYAN}Escolha uma opção (1-10): ${NC}"
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

# Função para enviar arquivo de teste para S3
send_test_file() {
    echo -e "\n${BLUE}📄 Enviar Arquivo de Teste para S3${NC}"
    
    echo "Buckets disponíveis:"
    echo "1. input-bucket (dispara fluxo S3 → SNS → SQS)"
    echo "2. output-bucket (simula resultado de processamento)"
    echo -n "Escolha o bucket (1-2): "
    read bucket_choice
    
    case $bucket_choice in
        1)
            bucket_name="input-bucket"
            file_prefix="teste-input"
            ;;
        2)
            bucket_name="output-bucket"
            file_prefix="teste-output"
            ;;
        *)
            echo -e "${RED}❌ Opção inválida${NC}"
            return 1
            ;;
    esac
    
    echo -e "\n${BLUE}Tipo de arquivo:${NC}"
    echo "1. Texto simples"
    echo "2. JSON de exemplo"
    echo "3. CSV de exemplo"
    echo "4. Arquivo personalizado"
    echo -n "Escolha o tipo (1-4): "
    read file_type
    
    timestamp=$(date +%Y%m%d-%H%M%S)
    temp_file="/tmp/${file_prefix}-${timestamp}"
    
    case $file_type in
        1)
            file_name="${file_prefix}-${timestamp}.txt"
            echo "Arquivo de teste criado em $(date)" > "$temp_file"
            echo "Bucket: $bucket_name" >> "$temp_file"
            echo "Timestamp: $timestamp" >> "$temp_file"
            echo "Conteúdo: Dados de teste para validação do fluxo LocalStack" >> "$temp_file"
            ;;
        2)
            file_name="${file_prefix}-${timestamp}.json"
            cat > "$temp_file" << EOF
{
    "timestamp": "$(date -Iseconds)",
    "bucket": "$bucket_name",
    "test_data": {
        "id": "$timestamp",
        "message": "Arquivo JSON de teste",
        "environment": "localstack-dev",
        "processed": false
    },
    "metadata": {
        "created_by": "dev-helpers",
        "version": "1.0"
    }
}
EOF
            ;;
        3)
            file_name="${file_prefix}-${timestamp}.csv"
            cat > "$temp_file" << EOF
id,timestamp,bucket,message,status
1,$(date -Iseconds),$bucket_name,Primeira linha de teste,pending
2,$(date -Iseconds),$bucket_name,Segunda linha de teste,pending
3,$(date -Iseconds),$bucket_name,Terceira linha de teste,pending
EOF
            ;;
        4)
            echo -n "Nome do arquivo (sem extensão): "
            read custom_name
            echo -n "Extensão do arquivo: "
            read custom_ext
            
            if [ -z "$custom_name" ] || [ -z "$custom_ext" ]; then
                echo -e "${RED}❌ Nome e extensão são obrigatórios${NC}"
                return 1
            fi
            
            file_name="${custom_name}-${timestamp}.${custom_ext}"
            echo -n "Conteúdo do arquivo: "
            read custom_content
            
            if [ -z "$custom_content" ]; then
                echo "Arquivo personalizado criado em $(date)" > "$temp_file"
            else
                echo "$custom_content" > "$temp_file"
            fi
            ;;
        *)
            echo -e "${RED}❌ Opção inválida${NC}"
            return 1
            ;;
    esac
    
    echo -e "\n${BLUE}Resumo do arquivo:${NC}"
    echo -e "${PURPLE}Nome: $file_name${NC}"
    echo -e "${PURPLE}Bucket: $bucket_name${NC}"
    echo -e "${PURPLE}Tamanho: $(wc -c < "$temp_file") bytes${NC}"
    echo -e "${PURPLE}Caminho temporário: $temp_file${NC}"
    
    echo -e "\n${BLUE}Preview do conteúdo:${NC}"
    echo -e "${CYAN}$(head -n 5 "$temp_file")${NC}"
    if [ $(wc -l < "$temp_file") -gt 5 ]; then
        echo -e "${CYAN}... (arquivo truncado)${NC}"
    fi
    
    echo -n -e "\n${YELLOW}Confirmar upload? (s/N): ${NC}"
    read confirm
    
    if [[ $confirm =~ ^[Ss]$ ]]; then
        echo -n "Enviando arquivo para S3... "
        
        if aws s3 cp "$temp_file" "s3://$bucket_name/$file_name" --endpoint-url=$AWS_ENDPOINT_URL; then
            echo -e "${GREEN}✅ Arquivo enviado com sucesso!${NC}"
            echo -e "${BLUE}📍 Localização: s3://$bucket_name/$file_name${NC}"
            
            if [ "$bucket_name" = "input-bucket" ]; then
                echo -e "${CYAN}🔄 Arquivo enviado para input-bucket${NC}"
                echo -e "${CYAN}⚡ Isso deve disparar: S3 → SNS → SQS${NC}"
                echo -e "${CYAN}💡 Use a opção 2 (listar mensagens SQS) para verificar${NC}"
                echo -e "${CYAN}💡 Ou use o monitor (./scripts/monitor.sh) para acompanhar${NC}"
            fi
        else
            echo -e "${RED}❌ Erro ao enviar arquivo${NC}"
        fi
    else
        echo -e "${BLUE}ℹ️  Upload cancelado${NC}"
    fi
    
    # Limpeza
    rm -f "$temp_file"
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
    echo -e "${PURPLE}📦 S3 Buckets:${NC}"
    buckets=$(aws s3 ls --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null)
    if [ -n "$buckets" ]; then
        echo "$buckets" | while read -r line; do
            bucket_name=$(echo "$line" | awk '{print $3}')
            echo -e "  ${GREEN}• $bucket_name${NC}"
        done
    else
        echo -e "  ${YELLOW}⚠️  Nenhum bucket encontrado${NC}"
    fi
    
    # SNS
    echo -e "${PURPLE}📢 SNS Topics:${NC}"
    topics=$(aws sns list-topics --endpoint-url=$AWS_ENDPOINT_URL --query 'Topics[].TopicArn' --output text 2>/dev/null)
    if [ -n "$topics" ]; then
        echo "$topics" | tr '\t' '\n' | while read -r topic_arn; do
            topic_name=$(echo "$topic_arn" | awk -F: '{print $6}')
            echo -e "  ${GREEN}• $topic_name${NC} (${BLUE}$topic_arn${NC})"
        done
    else
        echo -e "  ${YELLOW}⚠️  Nenhum tópico encontrado${NC}"
    fi
    
    # SQS
    echo -e "${PURPLE}📋 SQS Queues:${NC}"
    queues=$(aws sqs list-queues --endpoint-url=$AWS_ENDPOINT_URL --query 'QueueUrls[]' --output text 2>/dev/null)
    if [ -n "$queues" ]; then
        echo "$queues" | tr '\t' '\n' | while read -r queue_url; do
            queue_name=$(echo "$queue_url" | awk -F/ '{print $NF}')
            echo -e "  ${GREEN}• $queue_name${NC} (${BLUE}$queue_url${NC})"
        done
    else
        echo -e "  ${YELLOW}⚠️  Nenhuma fila encontrada${NC}"
    fi
    
    # Secrets
    echo -e "${PURPLE}🔐 Secrets:${NC}"
    secrets=$(aws secretsmanager list-secrets --endpoint-url=$AWS_ENDPOINT_URL --query 'SecretList[].Name' --output text 2>/dev/null)
    if [ -n "$secrets" ]; then
        echo "$secrets" | tr '\t' '\n' | while read -r secret_name; do
            echo -e "  ${GREEN}• $secret_name${NC}"
        done
    else
        echo -e "  ${YELLOW}⚠️  Nenhum secret encontrado${NC}"
    fi
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

# Função para adicionar nova secret
add_secret() {
    echo -e "\n${BLUE}➕ Adicionar Nova Secret${NC}"
    
    echo -n "Nome da secret: "
    read secret_name
    
    if [ -z "$secret_name" ]; then
        echo -e "${RED}❌ Nome da secret não pode estar vazio${NC}"
        return 1
    fi
    
    echo -n "Descrição da secret: "
    read secret_description
    
    if [ -z "$secret_description" ]; then
        secret_description="Secret criada via dev-helpers"
    fi
    
    echo -e "\n${BLUE}Escolha o formato da secret:${NC}"
    echo "1. Texto simples"
    echo "2. JSON (chave-valor)"
    echo -n "Escolha (1-2): "
    read format_choice
    
    case $format_choice in
        1)
            echo -n "Valor da secret: "
            read secret_value
            ;;
        2)
            echo -e "${BLUE}Adicione pares chave-valor (digite 'fim' para terminar):${NC}"
            secret_json="{"
            first=true
            
            while true; do
                echo -n "Chave (ou 'fim' para terminar): "
                read key
                
                if [ "$key" = "fim" ]; then
                    break
                fi
                
                if [ -z "$key" ]; then
                    echo -e "${RED}❌ Chave não pode estar vazia${NC}"
                    continue
                fi
                
                echo -n "Valor para '$key': "
                read value
                
                if [ -z "$value" ]; then
                    echo -e "${RED}❌ Valor não pode estar vazio${NC}"
                    continue
                fi
                
                if [ "$first" = true ]; then
                    first=false
                else
                    secret_json="$secret_json,"
                fi
                
                secret_json="$secret_json\"$key\":\"$value\""
            done
            
            secret_json="$secret_json}"
            secret_value="$secret_json"
            ;;
        *)
            echo -e "${RED}❌ Opção inválida${NC}"
            return 1
            ;;
    esac
    
    if [ -z "$secret_value" ]; then
        echo -e "${RED}❌ Valor da secret não pode estar vazio${NC}"
        return 1
    fi
    
    echo -e "\n${BLUE}Resumo da secret:${NC}"
    echo -e "${PURPLE}Nome: $secret_name${NC}"
    echo -e "${PURPLE}Descrição: $secret_description${NC}"
    echo -e "${PURPLE}Valor: $secret_value${NC}"
    
    echo -n -e "\n${YELLOW}Confirmar criação? (s/N): ${NC}"
    read confirm
    
    if [[ $confirm =~ ^[Ss]$ ]]; then
        echo -n "Criando secret... "
        
        result=$(aws secretsmanager create-secret \
            --name "$secret_name" \
            --description "$secret_description" \
            --secret-string "$secret_value" \
            --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Secret criada com sucesso!${NC}"
            secret_arn=$(echo "$result" | jq -r '.ARN' 2>/dev/null)
            if [ -n "$secret_arn" ] && [ "$secret_arn" != "null" ]; then
                echo -e "${BLUE}📋 ARN: $secret_arn${NC}"
            fi
        else
            echo -e "${RED}❌ Erro ao criar secret${NC}"
            
            # Tentar atualizar se já existe
            echo -n "Tentando atualizar secret existente... "
            result=$(aws secretsmanager update-secret \
                --secret-id "$secret_name" \
                --secret-string "$secret_value" \
                --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✅ Secret atualizada com sucesso!${NC}"
            else
                echo -e "${RED}❌ Erro ao criar/atualizar secret${NC}"
            fi
        fi
    else
        echo -e "${BLUE}ℹ️  Operação cancelada${NC}"
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
        4) send_test_file ;;
        5) watch_sqs_messages ;;
        6) clear_queues ;;
        7) quick_status ;;
        8) view_secrets ;;
        9) add_secret ;;
        10) 
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