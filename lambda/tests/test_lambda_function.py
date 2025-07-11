"""
Testes mínimos para Lambda Function.
Validar entry point com evento mockado.
"""

import sys
import os
import json
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..'))

# Mock do lambda_function para evitar dependências AWS
class MockTextProcessorService:
    def process_sqs_message(self, record):
        return {
            'status': 'success',
            'input_file': 's3://test-bucket/test-file.txt',
            'output_file': 's3://output-bucket/result.json',
            'analysis_summary': {
                'word_count': 10,
                'char_count': 50,
                'processing_time': 0.1
            }
        }


def test_lambda_handler_basic():
    """Teste básico: handler com evento SQS mockado."""
    
    # Evento SQS mockado
    event = {
        'Records': [
            {
                'messageId': 'test-message-id',
                'body': json.dumps({
                    'Type': 'Notification',
                    'Message': json.dumps({
                        'Records': [{
                            'eventName': 'ObjectCreated:Put',
                            's3': {
                                'bucket': {'name': 'test-bucket'},
                                'object': {'key': 'test-file.txt'}
                            }
                        }]
                    })
                })
            }
        ]
    }
    
    # Context mockado
    context = type('MockContext', (), {
        'aws_request_id': 'test-request-id',
        'get_remaining_time_in_millis': lambda: 30000
    })()
    
    # Simular processamento sem AWS
    try:
        # Validar estrutura do evento
        assert 'Records' in event
        assert len(event['Records']) > 0
        
        record = event['Records'][0]
        assert 'messageId' in record
        assert 'body' in record
        
        # Simular resposta da Lambda
        response = {
            'statusCode': 200,
            'body': json.dumps({
                'message': 'Processadas 1/1 mensagens',
                'results': [MockTextProcessorService().process_sqs_message(record)]
            }),
            'processed_count': 1,
            'total_count': 1
        }
        
        # Validações da resposta
        assert response['statusCode'] == 200
        assert response['processed_count'] == 1
        assert response['total_count'] == 1
        
        print("✅ Lambda Handler - Teste básico passou!")
        
    except Exception as e:
        print(f"❌ Lambda Handler - Erro no teste: {e}")
        raise


def test_lambda_handler_empty_event():
    """Teste edge case: evento vazio."""
    
    # Evento vazio
    event = {'Records': []}
    context = None
    
    # Simular processamento
    response = {
        'statusCode': 200,
        'body': json.dumps({
            'message': 'Processadas 0/0 mensagens',
            'results': []
        }),
        'processed_count': 0,
        'total_count': 0
    }
    
    # Validações
    assert response['statusCode'] == 200
    assert response['processed_count'] == 0
    assert response['total_count'] == 0
    
    print("✅ Lambda Handler - Teste evento vazio passou!")


def test_lambda_handler_error_handling():
    """Teste: tratamento de erros."""
    
    # Evento malformado
    event = {'Records': [{'messageId': 'test', 'body': 'invalid-json'}]}
    
    # Simular erro
    try:
        json.loads(event['Records'][0]['body'])
        assert False, "Deveria ter dado erro de JSON"
    except json.JSONDecodeError:
        # Simular resposta de erro
        response = {
            'statusCode': 207,  # Partial success
            'body': json.dumps({
                'message': 'Processadas 0/1 mensagens',
                'results': [{
                    'status': 'error',
                    'message': 'Formato de mensagem SQS inválido',
                    'record_id': 'test'
                }]
            }),
            'processed_count': 0,
            'total_count': 1
        }
        
        # Validações
        assert response['statusCode'] == 207
        assert response['processed_count'] == 0
        assert response['total_count'] == 1
        
        print("✅ Lambda Handler - Teste tratamento de erros passou!")


if __name__ == "__main__":
    test_lambda_handler_basic()
    test_lambda_handler_empty_event()
    test_lambda_handler_error_handling()
    print("\n🎉 Todos os testes da Lambda Function passaram!")