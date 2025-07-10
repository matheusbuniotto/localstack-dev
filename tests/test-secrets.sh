#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧪 Teste: Secrets Manager${NC}"
echo "============================"

# Carregando variáveis de ambiente
source .env-dev

# Função para verificar se valor existe
check_secret_value() {
    local secret_name=$1
    local expected_key=$2
    
    echo -n "Verificando secret '$secret_name'... "
    
    # Obter valor do secret
    secret_value=$(aws secretsmanager get-secret-value --secret-id "$secret_name" --endpoint-url=$AWS_ENDPOINT_URL --query 'SecretString' --output text 2>/dev/null)
    
    if [ $? -eq 0 ] && [ -n "$secret_value" ]; then
        echo -e "${GREEN}✅ Secret encontrado${NC}"
        
        # Verificar se contém a chave esperada
        if echo "$secret_value" | grep -q "$expected_key"; then
            echo -e "${GREEN}✅ Chave '$expected_key' encontrada no secret${NC}"
            return 0
        else
            echo -e "${RED}❌ Chave '$expected_key' não encontrada no secret${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ Secret não encontrado${NC}"
        return 1
    fi
}

# Função para criar/atualizar secret
create_test_secret() {
    local secret_name=$1
    local secret_value=$2
    
    echo -n "Criando/atualizando secret de teste '$secret_name'... "
    
    # Tentar criar o secret
    result=$(aws secretsmanager create-secret --name "$secret_name" --description "Secret de teste" --secret-string "$secret_value" --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Secret criado${NC}"
        return 0
    else
        # Se falhou, tentar atualizar
        result=$(aws secretsmanager update-secret --secret-id "$secret_name" --secret-string "$secret_value" --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null)
        
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✅ Secret atualizado${NC}"
            return 0
        else
            echo -e "${RED}❌ Falha ao criar/atualizar secret${NC}"
            return 1
        fi
    fi
}

# Função para deletar secret de teste
delete_test_secret() {
    local secret_name=$1
    
    echo -n "Removendo secret de teste '$secret_name'... "
    
    result=$(aws secretsmanager delete-secret --secret-id "$secret_name" --force-delete-without-recovery --endpoint-url=$AWS_ENDPOINT_URL 2>/dev/null)
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Secret removido${NC}"
    else
        echo -e "${YELLOW}⚠️  Secret pode não existir${NC}"
    fi
}

# 1. Testar secret existente (api-keys)
echo -e "\n${BLUE}🔍 Testando secret existente${NC}"
if check_secret_value "$SECRET_NAME" "api_key_1"; then
    echo -e "${GREEN}✅ Secret '$SECRET_NAME' está funcionando corretamente${NC}"
else
    echo -e "${RED}❌ Problemas com secret '$SECRET_NAME'${NC}"
    exit 1
fi

# 2. Testar criação/leitura de novo secret
echo -e "\n${BLUE}🔧 Testando criação de novo secret${NC}"
test_secret_name="test-secret-$(date +%s)"
test_secret_value='{"test_key": "test_value", "another_key": "another_value"}'

if create_test_secret "$test_secret_name" "$test_secret_value"; then
    echo -e "${GREEN}✅ Criação de secret funcionando${NC}"
else
    echo -e "${RED}❌ Falha na criação de secret${NC}"
    exit 1
fi

# 3. Testar leitura do secret criado
echo -e "\n${BLUE}🔍 Testando leitura do secret criado${NC}"
if check_secret_value "$test_secret_name" "test_key"; then
    echo -e "${GREEN}✅ Leitura de secret funcionando${NC}"
else
    echo -e "${RED}❌ Falha na leitura de secret${NC}"
    delete_test_secret "$test_secret_name"
    exit 1
fi

# 4. Testar atualização de secret
echo -e "\n${BLUE}🔄 Testando atualização de secret${NC}"
updated_secret_value='{"test_key": "updated_value", "new_key": "new_value"}'

if create_test_secret "$test_secret_name" "$updated_secret_value"; then
    echo -e "${GREEN}✅ Atualização de secret funcionando${NC}"
else
    echo -e "${RED}❌ Falha na atualização de secret${NC}"
    delete_test_secret "$test_secret_name"
    exit 1
fi

# 5. Verificar se a atualização foi aplicada
echo -e "\n${BLUE}🔍 Verificando atualização aplicada${NC}"
if check_secret_value "$test_secret_name" "new_key"; then
    echo -e "${GREEN}✅ Atualização aplicada corretamente${NC}"
else
    echo -e "${RED}❌ Atualização não foi aplicada${NC}"
    delete_test_secret "$test_secret_name"
    exit 1
fi

# 6. Limpeza - remover secret de teste
echo -e "\n${BLUE}🧹 Limpando secret de teste${NC}"
delete_test_secret "$test_secret_name"

echo -e "\n${GREEN}🎉 Todos os testes do Secrets Manager passaram!${NC}"
echo "✅ Operações testadas: Criar, Ler, Atualizar, Deletar"
echo -e "${BLUE}📊 Teste Secrets Manager concluído com sucesso!${NC}"