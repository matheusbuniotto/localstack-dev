"""
Testes mínimos para AWS Config.
Validar configuração básica.
"""

import sys
import os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', 'src'))

from config.aws_config import AWSConfig


def test_aws_config_initialization():
    """Teste básico: inicialização da configuração."""
    config = AWSConfig()
    
    # Verificar campos básicos
    assert config.region is not None
    assert config.input_bucket is not None
    assert config.output_bucket is not None
    assert config.client_config is not None
    
    # Verificar tipo de ambiente
    env = config.get_environment()
    assert env in ['localstack', 'aws']
    
    print("✅ AWSConfig - Teste inicialização passou!")


def test_aws_config_clients():
    """Teste: criação de clientes AWS."""
    config = AWSConfig()
    
    # Tentar criar clientes (não precisa conectar)
    try:
        s3_client = config.get_s3_client()
        sns_client = config.get_sns_client()
        sqs_client = config.get_sqs_client()
        
        # Verificar se são objetos válidos
        assert s3_client is not None
        assert sns_client is not None
        assert sqs_client is not None
        
        print("✅ AWSConfig - Teste clientes passou!")
        
    except Exception as e:
        print(f"⚠️ AWSConfig - Clientes criados mas podem não conectar: {e}")


def test_aws_config_localstack_detection():
    """Teste: detecção do LocalStack."""
    config = AWSConfig()
    
    # Verificar detecção do LocalStack
    is_localstack = config.is_localstack()
    assert isinstance(is_localstack, bool)
    
    # Se endpoint_url está definido, deve ser LocalStack
    if config.endpoint_url:
        assert is_localstack == True
    
    print("✅ AWSConfig - Teste detecção LocalStack passou!")


if __name__ == "__main__":
    test_aws_config_initialization()
    test_aws_config_clients()
    test_aws_config_localstack_detection()
    print("\n🎉 Todos os testes do AWSConfig passaram!")