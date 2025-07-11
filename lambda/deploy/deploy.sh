#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🚀 Deploy Lambda para LocalStack${NC}"
echo "================================="

# Configurações
LAMBDA_NAME="text-processor-lambda"
LAMBDA_ZIP="text-processor-lambda.zip"
LAMBDA_ROLE="arn:aws:iam::000000000000:role/lambda-execution-role"
LAMBDA_HANDLER="lambda_function.lambda_handler"
LAMBDA_RUNTIME="python3.11"
LAMBDA_TIMEOUT=30
LAMBDA_MEMORY=256

# Carregando variáveis de ambiente
if [ -f "../../.env-dev" ]; then
    source ../../.env-dev
else
    echo -e "${RED}❌ Arquivo .env-dev não encontrado${NC}"
    exit 1
fi

# Verificar se LocalStack está rodando
if ! curl -sf http://localhost:4566/_localstack/health >/dev/null 2>&1; then
    echo -e "${RED}❌ LocalStack não está rodando${NC}"
    echo -e "${YELLOW}💡 Execute: ./start.sh${NC}"
    exit 1
fi

# Função para executar testes
run_tests() {
    echo -e "\n${BLUE}🧪 Executando testes...${NC}"
    
    if python ../tests/run_tests.py; then
        echo -e "${GREEN}✅ Todos os testes passaram!${NC}"
        return 0
    else
        echo -e "${RED}❌ Testes falharam. Deploy cancelado.${NC}"
        return 1
    fi
}

# Função para criar pacote Lambda
create_package() {
    echo -e "\n${BLUE}📦 Criando pacote Lambda...${NC}"
    
    # Limpar pacote anterior
    rm -f "$LAMBDA_ZIP"
    
    # Criar diretório temporário
    TEMP_DIR=$(mktemp -d)
    echo -e "${BLUE}📁 Diretório temporário: $TEMP_DIR${NC}"
    
    # Copiar código fonte
    cp -r ../src "$TEMP_DIR/"
    cp ../lambda_function.py "$TEMP_DIR/"
    cp ../requirements.txt "$TEMP_DIR/"
    
    # Instalar dependências
    echo -e "${BLUE}📦 Instalando dependências...${NC}"
    pip install -r "$TEMP_DIR/requirements.txt" -t "$TEMP_DIR/" --quiet
    
    # Criar ZIP
    cd "$TEMP_DIR"
    zip -r "$OLDPWD/$LAMBDA_ZIP" . -x "*.pyc" "__pycache__/*" "*.git*" > /dev/null
    
    # Limpeza
    cd "$OLDPWD"
    rm -rf "$TEMP_DIR"
    
    if [ -f "$LAMBDA_ZIP" ]; then
        echo -e "${GREEN}✅ Pacote criado: $LAMBDA_ZIP ($(du -h $LAMBDA_ZIP | cut -f1))${NC}"
        return 0
    else
        echo -e "${RED}❌ Erro ao criar pacote${NC}"
        return 1
    fi
}

# Função para criar role IAM
create_iam_role() {
    echo -e "\n${BLUE}🔐 Criando role IAM...${NC}"
    
    # Política de confiança
    cat > trust-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": {
                "Service": "lambda.amazonaws.com"
            },
            "Action": "sts:AssumeRole"
        }
    ]
}
EOF
    
    # Criar role
    aws iam create-role \
        --role-name lambda-execution-role \
        --assume-role-policy-document file://trust-policy.json \
        --endpoint-url=$AWS_ENDPOINT_URL &>/dev/null
    
    # Política de execução
    cat > execution-policy.json << EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "logs:CreateLogGroup",
                "logs:CreateLogStream",
                "logs:PutLogEvents",
                "s3:GetObject",
                "s3:PutObject",
                "sns:Publish",
                "sqs:ReceiveMessage",
                "sqs:DeleteMessage",
                "secretsmanager:GetSecretValue"
            ],
            "Resource": "*"
        }
    ]
}
EOF
    
    # Anexar política
    aws iam put-role-policy \
        --role-name lambda-execution-role \
        --policy-name lambda-execution-policy \
        --policy-document file://execution-policy.json \
        --endpoint-url=$AWS_ENDPOINT_URL &>/dev/null
    
    # Limpeza
    rm -f trust-policy.json execution-policy.json
    
    echo -e "${GREEN}✅ Role IAM criada${NC}"
}

# Função para fazer deploy da Lambda
deploy_lambda() {
    echo -e "\n${BLUE}🚀 Fazendo deploy da Lambda...${NC}"
    
    # Tentar atualizar primeiro
    echo -e "${BLUE}🔄 Tentando atualizar Lambda existente...${NC}"
    
    if aws lambda update-function-code \
        --function-name "$LAMBDA_NAME" \
        --zip-file fileb://"$LAMBDA_ZIP" \
        --endpoint-url=$AWS_ENDPOINT_URL &>/dev/null; then
        
        echo -e "${GREEN}✅ Lambda atualizada com sucesso!${NC}"
        return 0
    fi
    
    # Se não existe, criar nova
    echo -e "${BLUE}🆕 Criando nova Lambda...${NC}"
    
    if aws lambda create-function \
        --function-name "$LAMBDA_NAME" \
        --runtime "$LAMBDA_RUNTIME" \
        --role "$LAMBDA_ROLE" \
        --handler "$LAMBDA_HANDLER" \
        --zip-file fileb://"$LAMBDA_ZIP" \
        --timeout "$LAMBDA_TIMEOUT" \
        --memory-size "$LAMBDA_MEMORY" \
        --environment Variables="{AWS_ENDPOINT_URL=$AWS_ENDPOINT_URL,S3_INPUT_BUCKET=$S3_INPUT_BUCKET,S3_OUTPUT_BUCKET=$S3_OUTPUT_BUCKET,SNS_OUTPUT_TOPIC_ARN=arn:aws:sns:us-east-1:000000000000:output-topic}" \
        --endpoint-url=$AWS_ENDPOINT_URL &>/dev/null; then
        
        echo -e "${GREEN}✅ Lambda criada com sucesso!${NC}"
        return 0
    else
        echo -e "${RED}❌ Erro ao criar Lambda${NC}"
        return 1
    fi
}

# Função para conectar SQS à Lambda
connect_sqs_trigger() {
    echo -e "\n${BLUE}🔗 Conectando SQS à Lambda...${NC}"
    
    # Obter ARN da fila
    QUEUE_ARN=$(aws sqs get-queue-attributes \
        --queue-url "http://sqs.us-east-1.localhost.localstack.cloud:4566/000000000000/input-queue" \
        --attribute-names QueueArn \
        --endpoint-url=$AWS_ENDPOINT_URL \
        --query 'Attributes.QueueArn' --output text)
    
    # Criar event source mapping
    aws lambda create-event-source-mapping \
        --function-name "$LAMBDA_NAME" \
        --event-source-arn "$QUEUE_ARN" \
        --batch-size 1 \
        --endpoint-url=$AWS_ENDPOINT_URL &>/dev/null
    
    echo -e "${GREEN}✅ SQS conectada à Lambda${NC}"
}

# Função para testar deployment
test_deployment() {
    echo -e "\n${BLUE}🧪 Testando deployment...${NC}"
    
    # Testar invocação direta
    echo '{"Records": [{"messageId": "test", "body": "{\\"Type\\": \\"Notification\\", \\"Message\\": \\"{\\\\\\"Records\\\\\\": [{\\\\\\"eventName\\\\\\": \\\\\\"ObjectCreated:Put\\\\\\", \\\\\\"s3\\\\\\": {\\\\\\"bucket\\\\\\": {\\\\\\"name\\\\\\": \\\\\\"input-bucket\\\\\\"}, \\\\\\"object\\\\\\": {\\\\\\"key\\\\\\": \\\\\\"test.txt\\\\\\"}}}]}\\"}"}]}' > test-event.json
    
    if aws lambda invoke \
        --function-name "$LAMBDA_NAME" \
        --payload file://test-event.json \
        --endpoint-url=$AWS_ENDPOINT_URL \
        response.json &>/dev/null; then
        
        echo -e "${GREEN}✅ Teste de invocação passou!${NC}"
        
        # Mostrar resposta
        if [ -f response.json ]; then
            echo -e "${BLUE}📋 Resposta da Lambda:${NC}"
            cat response.json | jq . 2>/dev/null || cat response.json
        fi
        
        # Limpeza
        rm -f test-event.json response.json
        return 0
    else
        echo -e "${RED}❌ Teste de invocação falhou${NC}"
        rm -f test-event.json response.json
        return 1
    fi
}

# Função principal
main() {
    echo -e "${CYAN}Iniciando deploy da Lambda...${NC}"
    
    # Executar pipeline
    run_tests || exit 1
    create_package || exit 1
    create_iam_role
    deploy_lambda || exit 1
    connect_sqs_trigger
    test_deployment || exit 1
    
    # Limpeza
    rm -f "$LAMBDA_ZIP"
    
    echo -e "\n${GREEN}🎉 Deploy concluído com sucesso!${NC}"
    echo -e "${CYAN}📋 Próximos passos:${NC}"
    echo -e "${BLUE}  1. Teste envio de arquivo: ./scripts/dev-helpers.sh (opção 4)${NC}"
    echo -e "${BLUE}  2. Monitore processamento: ./scripts/monitor.sh${NC}"
    echo -e "${BLUE}  3. Verifique logs: docker logs localstack-main${NC}"
}

# Executar
main