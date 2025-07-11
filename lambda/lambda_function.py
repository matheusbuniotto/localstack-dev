import json
import os
import sys
from typing import Dict, Any

# Adicionar src ao path para imports
sys.path.insert(0, os.path.join(os.path.dirname(__file__), 'src'))

from services.text_processor_service import TextProcessorService
from utils.logger import setup_logger

logger = setup_logger()


def lambda_handler(event: Dict[str, Any], context: Any) -> Dict[str, Any]:
    """
    Entry point da Lambda para processar arquivos de texto.
    
    Args:
        event: Evento SQS com informações do arquivo S3
        context: Contexto da Lambda
        
    Returns:
        Resposta com status do processamento
    """
    try:
        logger.info(f"Processando evento: {json.dumps(event, indent=2)}")
        
        # Inicializar serviço de processamento
        processor = TextProcessorService()
        
        # Processar cada mensagem SQS
        results = []
        for record in event.get('Records', []):
            try:
                # Processar mensagem individual
                result = processor.process_sqs_message(record)
                results.append(result)
                logger.info(f"Mensagem processada com sucesso: {result}")
                
            except Exception as e:
                logger.error(f"Erro ao processar mensagem: {str(e)}")
                results.append({
                    'status': 'error',
                    'message': str(e),
                    'record_id': record.get('messageId', 'unknown')
                })
        
        # Resposta consolidada
        success_count = sum(1 for r in results if r.get('status') == 'success')
        total_count = len(results)
        
        response = {
            'statusCode': 200 if success_count == total_count else 207,  # 207 = Partial Success
            'body': json.dumps({
                'message': f'Processadas {success_count}/{total_count} mensagens',
                'results': results
            }),
            'processed_count': success_count,
            'total_count': total_count
        }
        
        logger.info(f"Processamento concluído: {success_count}/{total_count} sucessos")
        return response
        
    except Exception as e:
        logger.error(f"Erro crítico na Lambda: {str(e)}")
        return {
            'statusCode': 500,
            'body': json.dumps({
                'error': 'Erro interno da Lambda',
                'message': str(e)
            })
        }