#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo -e "${CYAN}🧪 Executando Todos os Testes LocalStack${NC}"
echo "=========================================="

# Verificar se LocalStack está rodando
if ! docker ps | grep -q localstack-main; then
    echo -e "${RED}❌ LocalStack não está rodando${NC}"
    echo -e "${YELLOW}💡 Execute: ./start.sh${NC}"
    exit 1
fi

# Contadores
total_tests=0
passed_tests=0
failed_tests=0

# Função para executar teste
run_test() {
    local test_name=$1
    local test_script=$2
    
    echo -e "\n${BLUE}═══════════════════════════════════════════${NC}"
    echo -e "${BLUE}🧪 Executando: $test_name${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════${NC}"
    
    ((total_tests++))
    
    if "./$test_script"; then
        echo -e "${GREEN}✅ PASSOU: $test_name${NC}"
        ((passed_tests++))
        return 0
    else
        echo -e "${RED}❌ FALHOU: $test_name${NC}"
        ((failed_tests++))
        return 1
    fi
}

# Executar health check primeiro
echo -e "\n${CYAN}🔍 Verificando saúde do ambiente...${NC}"
if ! ./scripts/health-check.sh; then
    echo -e "${RED}❌ Health check falhou. Parando execução dos testes.${NC}"
    exit 1
fi

echo -e "\n${CYAN}🚀 Iniciando testes funcionais...${NC}"

# Lista de testes para executar
tests=(
    "S3 Events Test:tests/test-s3-events.sh"
    "SNS-SQS Test:tests/test-sns-sqs.sh"
    "Secrets Manager Test:tests/test-secrets.sh"
)

# Executar todos os testes
for test in "${tests[@]}"; do
    IFS=':' read -r test_name test_script <<< "$test"
    run_test "$test_name" "$test_script"
done

# Relatório final
echo -e "\n${CYAN}📊 RELATÓRIO FINAL DOS TESTES${NC}"
echo "=========================================="
echo -e "${BLUE}Total de testes executados: $total_tests${NC}"
echo -e "${GREEN}Testes que passaram: $passed_tests${NC}"
echo -e "${RED}Testes que falharam: $failed_tests${NC}"

if [ $failed_tests -eq 0 ]; then
    echo -e "\n${GREEN}🎉 TODOS OS TESTES PASSARAM!${NC}"
    echo -e "${GREEN}✅ Ambiente LocalStack está funcionando perfeitamente${NC}"
    echo -e "${GREEN}✅ Todos os fluxos de evento estão operacionais${NC}"
    echo -e "${GREEN}✅ Secrets Manager está funcionando corretamente${NC}"
    exit 0
else
    echo -e "\n${RED}❌ ALGUNS TESTES FALHARAM${NC}"
    echo -e "${YELLOW}⚠️  Verifique os logs acima para mais detalhes${NC}"
    echo -e "${YELLOW}💡 Tente executar: ./start.sh para reinicializar o ambiente${NC}"
    exit 1
fi