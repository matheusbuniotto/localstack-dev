#!/bin/bash

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🛑 Parando Ambiente LocalStack${NC}"
echo "=================================="

# Função para verificar se container está rodando
check_container() {
    if docker ps | grep -q localstack-main; then
        return 0
    else
        return 1
    fi
}

# Função para parar container
stop_container() {
    echo -n "🔴 Parando container LocalStack... "
    if docker compose down; then
        echo -e "${GREEN}✅ Container parado${NC}"
        return 0
    else
        echo -e "${RED}❌ Erro ao parar container${NC}"
        return 1
    fi
}

# Função para limpeza completa
full_cleanup() {
    echo -e "\n${YELLOW}🧹 Limpeza completa solicitada${NC}"
    
    # Parar containers
    echo -n "🔴 Parando todos os containers... "
    docker compose down --volumes --remove-orphans &>/dev/null
    echo -e "${GREEN}✅ Containers parados${NC}"
    
    # Remover volumes
    echo -n "🗑️  Removendo volumes... "
    docker volume ls -q | grep localstack | xargs -r docker volume rm &>/dev/null
    echo -e "${GREEN}✅ Volumes removidos${NC}"
    
    # Remover imagens (opcional)
    if [ "$1" = "--remove-images" ]; then
        echo -n "🗑️  Removendo imagens LocalStack... "
        docker images | grep localstack | awk '{print $3}' | xargs -r docker rmi &>/dev/null
        echo -e "${GREEN}✅ Imagens removidas${NC}"
    fi
    
    # Limpar arquivos temporários
    echo -n "🧹 Limpando arquivos temporários... "
    rm -rf /tmp/test-* &>/dev/null
    echo -e "${GREEN}✅ Arquivos temporários limpos${NC}"
}

# Verificar argumentos
case "$1" in
    --clean)
        full_cleanup
        echo -e "\n${GREEN}🎉 Limpeza completa realizada!${NC}"
        ;;
    --reset)
        full_cleanup --remove-images
        echo -e "\n${GREEN}🎉 Reset completo realizado!${NC}"
        echo -e "${BLUE}💡 Para reiniciar: ./start.sh${NC}"
        ;;
    --help)
        echo -e "\n${BLUE}📖 Uso do script stop.sh:${NC}"
        echo "  ./stop.sh           - Para apenas o container"
        echo "  ./stop.sh --clean   - Para container e remove volumes"
        echo "  ./stop.sh --reset   - Para tudo e remove imagens"
        echo "  ./stop.sh --help    - Mostra esta ajuda"
        exit 0
        ;;
    "")
        # Parada simples
        if check_container; then
            stop_container
            echo -e "\n${GREEN}✅ LocalStack parado com sucesso${NC}"
            echo -e "${BLUE}💡 Para reiniciar: ./start.sh${NC}"
            echo -e "${BLUE}💡 Para limpeza completa: ./stop.sh --clean${NC}"
        else
            echo -e "${YELLOW}⚠️  LocalStack não está rodando${NC}"
        fi
        ;;
    *)
        echo -e "${RED}❌ Opção inválida: $1${NC}"
        echo -e "${BLUE}💡 Use: ./stop.sh --help para ver opções${NC}"
        exit 1
        ;;
esac

echo -e "\n${BLUE}📊 Status final:${NC}"
if check_container; then
    echo -e "${YELLOW}⚠️  Container ainda rodando${NC}"
else
    echo -e "${GREEN}✅ Container parado${NC}"
fi