#!/usr/bin/env python3
"""
Script para executar todos os testes mínimos da Lambda.
Abordagem TDD - testes rápidos e focados.
"""

import sys
import os
import traceback

# Adicionar paths necessários
current_dir = os.path.dirname(__file__)
lambda_dir = os.path.join(current_dir, '..')
sys.path.insert(0, lambda_dir)
sys.path.insert(0, os.path.join(lambda_dir, 'src'))

def run_test_module(module_name):
    """Executa um módulo de teste."""
    print(f"\n{'='*50}")
    print(f"🧪 Executando {module_name}")
    print('='*50)
    
    try:
        # Importar e executar módulo
        module = __import__(module_name)
        
        # Executar função main se existir
        if hasattr(module, '__main__'):
            exec(open(f"{module_name}.py").read())
        else:
            print(f"⚠️ Módulo {module_name} não tem função main")
            
        return True
        
    except Exception as e:
        print(f"❌ Erro ao executar {module_name}: {e}")
        traceback.print_exc()
        return False


def main():
    """Executa todos os testes mínimos."""
    print("🚀 Iniciando testes mínimos da Lambda")
    print("Abordagem TDD - Validação rápida da implementação")
    
    # Lista de módulos de teste
    test_modules = [
        'test_text_analyzer',
        'test_aws_config', 
        'test_lambda_function'
    ]
    
    results = []
    
    # Executar cada módulo
    for module in test_modules:
        success = run_test_module(module)
        results.append((module, success))
    
    # Resumo final
    print(f"\n{'='*50}")
    print("📊 RESUMO DOS TESTES")
    print('='*50)
    
    passed = sum(1 for _, success in results if success)
    total = len(results)
    
    for module, success in results:
        status = "✅ PASSOU" if success else "❌ FALHOU"
        print(f"{module:<25} {status}")
    
    print(f"\n📈 Resultado: {passed}/{total} testes passaram")
    
    if passed == total:
        print("🎉 Todos os testes passaram! Lambda pronta para deploy.")
        return 0
    else:
        print("⚠️ Alguns testes falharam. Corrija antes do deploy.")
        return 1


if __name__ == "__main__":
    exit_code = main()
    sys.exit(exit_code)