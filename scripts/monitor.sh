#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

echo -e "${CYAN}📊 LocalStack - Monitor Simples${NC}"
echo "================================="

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
    echo -e "\n${BLUE}📋 Opções de Monitoramento:${NC}"
    echo "1. 📊 Dashboard em tempo real"
    echo "2. 📜 Logs do LocalStack"
    echo "3. 🔍 Verificar saúde dos serviços"
    echo "4. 📈 Contadores de mensagens"
    echo "5. 🚨 Alertas de problemas"
    echo "6. 🚪 Sair"
    echo -n -e "${CYAN}Escolha uma opção (1-6): ${NC}"
}

# Função para dashboard em tempo real
real_time_dashboard() {
    echo -e "${CYAN}📊 Dashboard em Tempo Real - Pressione Ctrl+C para sair${NC}"
    
    while true; do
        clear
        echo -e "${CYAN}📊 LocalStack Monitor - $(date '+%H:%M:%S')${NC}"
        echo "=================================================="
        
        # Status do container
        echo -e "\n${BLUE}🐳 Container Status:${NC}"
        if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep localstack-main; then
            echo -e "${GREEN}✅ LocalStack rodando${NC}"
        else
            echo -e "${RED}❌ LocalStack parado${NC}"
        fi
        
        # Contadores rápidos
        echo -e "\n${BLUE}📊 Contadores:${NC}"
        
        # SQS message count
        for queue in "input-queue" "output-queue"; do
            queue_url="http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/$queue"
            
            # Usar approximate message count
            attrs=$(aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names ApproximateNumberOfMessages --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null)
            
            if [ $? -eq 0 ]; then
                msg_count=$(echo "$attrs" | jq -r '.Attributes.ApproximateNumberOfMessages // "0"' 2>/dev/null || echo "0")
                if [ "$msg_count" -gt 0 ]; then
                    echo -e "${YELLOW}📋 $queue: $msg_count mensagens${NC}"
                else
                    echo -e "${GREEN}📋 $queue: $msg_count mensagens${NC}"
                fi
            else
                echo -e "${RED}📋 $queue: erro ao consultar${NC}"
            fi
        done
        
        # S3 object count
        for bucket in "input-bucket" "output-bucket"; do
            obj_count=$(aws s3 ls s3://$bucket/ --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null | wc -l)
            echo -e "${BLUE}📦 $bucket: $obj_count arquivos${NC}"
        done
        
        # Health check rápido
        echo -e "\n${BLUE}🔍 Health Check:${NC}"
        if curl -sf http://localhost:4566/_localstack/health >/dev/null 2>&1; then
            echo -e "${GREEN}✅ Endpoint respondendo${NC}"
        else
            echo -e "${RED}❌ Endpoint não responde${NC}"
        fi
        
        echo -e "\n${PURPLE}🔄 Atualizando em 5 segundos...${NC}"
        sleep 5
    done
}

# Função para mostrar logs
show_logs() {
    echo -e "${CYAN}📜 Logs do LocalStack - Pressione Ctrl+C para sair${NC}"
    echo "=================================================="
    
    # Mostrar logs em tempo real
    docker logs -f localstack-main --tail 50
}

# Função para verificar saúde
health_check() {
    echo -e "\n${BLUE}🔍 Verificação de Saúde Detalhada${NC}"
    echo "=================================="
    
    # Usar o health check script existente
    if [ -f "scripts/health-check.sh" ]; then
        ./scripts/health-check.sh
    else
        echo -e "${YELLOW}⚠️  Script health-check.sh não encontrado${NC}"
        echo -e "${BLUE}Fazendo verificação básica...${NC}"
        
        # Verificação básica
        echo -n "LocalStack endpoint: "
        if curl -sf http://localhost:4566/_localstack/health >/dev/null 2>&1; then
            echo -e "${GREEN}✅ OK${NC}"
        else
            echo -e "${RED}❌ Falha${NC}"
        fi
    fi
}

# Função para contadores de mensagens
message_counters() {
    echo -e "\n${BLUE}📈 Contadores de Mensagens${NC}"
    echo "=========================="
    
    for queue in "input-queue" "output-queue"; do
        echo -e "\n${PURPLE}📋 Fila: $queue${NC}"
        queue_url="http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/$queue"
        
        # Obter atributos da fila
        attrs=$(aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names All --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            visible=$(echo "$attrs" | jq -r '.Attributes.ApproximateNumberOfMessages // "0"' 2>/dev/null || echo "0")
            not_visible=$(echo "$attrs" | jq -r '.Attributes.ApproximateNumberOfMessagesNotVisible // "0"' 2>/dev/null || echo "0")
            
            echo -e "${BLUE}  📊 Mensagens visíveis: $visible${NC}"
            echo -e "${BLUE}  📊 Mensagens sendo processadas: $not_visible${NC}"
            
            total=$((visible + not_visible))
            echo -e "${BLUE}  📊 Total: $total${NC}"
            
            if [ $total -gt 10 ]; then
                echo -e "${YELLOW}  ⚠️  Muitas mensagens acumuladas${NC}"
            elif [ $total -gt 0 ]; then
                echo -e "${GREEN}  ✅ Fila com atividade normal${NC}"
            else
                echo -e "${GREEN}  ✅ Fila vazia${NC}"
            fi
        else
            echo -e "${RED}  ❌ Erro ao consultar fila${NC}"
        fi
    done
}

# Função para alertas
check_alerts() {
    echo -e "\n${BLUE}🚨 Verificação de Alertas${NC}"
    echo "========================="
    
    alerts=0
    
    # Verificar se container está rodando
    if ! docker ps | grep -q localstack-main; then
        echo -e "${RED}🚨 ALERTA: LocalStack não está rodando${NC}"
        ((alerts++))
    fi
    
    # Verificar endpoint
    if ! curl -sf http://localhost:4566/_localstack/health >/dev/null 2>&1; then
        echo -e "${RED}🚨 ALERTA: Endpoint não responde${NC}"
        ((alerts++))
    fi
    
    # Verificar filas com muitas mensagens
    for queue in "input-queue" "output-queue"; do
        queue_url="http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/$queue"
        attrs=$(aws sqs get-queue-attributes --queue-url "$queue_url" --attribute-names ApproximateNumberOfMessages --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            msg_count=$(echo "$attrs" | jq -r '.Attributes.ApproximateNumberOfMessages // "0"' 2>/dev/null || echo "0")
            if [ "$msg_count" -gt 50 ]; then
                echo -e "${YELLOW}⚠️  AVISO: Fila $queue com $msg_count mensagens acumuladas${NC}"
                ((alerts++))
            fi
        fi
    done
    
    # Verificar uso de memória do container
    memory_usage=$(docker stats localstack-main --no-stream --format "{{.MemPerc}}" 2>/dev/null | sed 's/%//')
    if [ -n "$memory_usage" ] && [ "${memory_usage%.*}" -gt 80 ]; then
        echo -e "${YELLOW}⚠️  AVISO: Uso de memória alto: $memory_usage%${NC}"
        ((alerts++))
    fi
    
    if [ $alerts -eq 0 ]; then
        echo -e "${GREEN}✅ Nenhum alerta - Sistema funcionando normalmente${NC}"
    else
        echo -e "${YELLOW}⚠️  Total de alertas: $alerts${NC}"
    fi
}

# Loop principal
while true; do
    show_menu
    read choice
    
    case $choice in
        1) real_time_dashboard ;;
        2) show_logs ;;
        3) health_check ;;
        4) message_counters ;;
        5) check_alerts ;;
        6) 
            echo -e "${GREEN}👋 Saindo do monitor...${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}❌ Opção inválida. Tente novamente.${NC}"
            ;;
    esac
    
    echo -e "\n${BLUE}Pressione Enter para continuar...${NC}"
    read
done