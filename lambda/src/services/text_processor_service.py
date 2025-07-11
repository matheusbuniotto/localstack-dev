import json
import os
import re
from datetime import datetime
from typing import Dict, Any, List
from collections import Counter

from config.aws_config import AWSConfig
from core.text_analyzer import TextAnalyzer
from utils.logger import setup_logger

logger = setup_logger()


class TextProcessorService:
    """
    Serviço principal para processar arquivos de texto.
    Orquestra todo o fluxo: S3 -> Análise -> S3 -> SNS
    """
    
    def __init__(self):
        self.aws_config = AWSConfig()
        self.s3_client = self.aws_config.get_s3_client()
        self.sns_client = self.aws_config.get_sns_client()
        self.analyzer = TextAnalyzer()
    
    def process_sqs_message(self, sqs_record: Dict[str, Any]) -> Dict[str, Any]:
        """
        Processa uma mensagem SQS que contém informações do arquivo S3.
        
        Args:
            sqs_record: Record da mensagem SQS
            
        Returns:
            Resultado do processamento
        """
        try:
            # Extrair informações do S3 da mensagem SQS
            s3_info = self._extract_s3_info_from_sqs(sqs_record)
            
            # Baixar arquivo do S3
            file_content = self._download_file_from_s3(
                s3_info['bucket'], 
                s3_info['key']
            )
            
            # Analisar texto
            analysis = self.analyzer.analyze_text(file_content)
            
            # Enriquecer análise com metadados
            enriched_analysis = self._enrich_analysis(analysis, s3_info)
            
            # Salvar resultado no S3
            output_key = self._save_analysis_to_s3(enriched_analysis, s3_info['key'])
            
            # Enviar notificação SNS
            self._send_notification(enriched_analysis, output_key)
            
            return {
                'status': 'success',
                'input_file': f"s3://{s3_info['bucket']}/{s3_info['key']}",
                'output_file': f"s3://{self.aws_config.output_bucket}/{output_key}",
                'analysis_summary': {
                    'word_count': analysis['word_count'],
                    'char_count': analysis['char_count'],
                    'processing_time': analysis['processing_time']
                }
            }
            
        except Exception as e:
            logger.error(f"Erro no processamento: {str(e)}")
            raise
    
    def _extract_s3_info_from_sqs(self, sqs_record: Dict[str, Any]) -> Dict[str, str]:
        """Extrai informações do S3 da mensagem SQS."""
        try:
            # Parsear body da mensagem SQS
            body = json.loads(sqs_record['body'])
            
            # Extrair informações do SNS
            if 'Message' in body:
                sns_message = json.loads(body['Message'])
                
                # Buscar informações do S3 no SNS
                if 'Records' in sns_message:
                    s3_record = sns_message['Records'][0]
                    bucket = s3_record['s3']['bucket']['name']
                    key = s3_record['s3']['object']['key']
                    
                    return {
                        'bucket': bucket,
                        'key': key,
                        'event_name': s3_record['eventName']
                    }
            
            raise ValueError("Não foi possível extrair informações do S3 da mensagem SQS")
            
        except (json.JSONDecodeError, KeyError) as e:
            raise ValueError(f"Formato de mensagem SQS inválido: {str(e)}")
    
    def _download_file_from_s3(self, bucket: str, key: str) -> str:
        """Baixa arquivo do S3 e retorna conteúdo como string."""
        try:
            logger.info(f"Baixando arquivo s3://{bucket}/{key}")
            
            response = self.s3_client.get_object(Bucket=bucket, Key=key)
            content = response['Body'].read().decode('utf-8')
            
            logger.info(f"Arquivo baixado com sucesso: {len(content)} caracteres")
            return content
            
        except Exception as e:
            raise Exception(f"Erro ao baixar arquivo do S3: {str(e)}")
    
    def _enrich_analysis(self, analysis: Dict[str, Any], s3_info: Dict[str, str]) -> Dict[str, Any]:
        """Enriquece análise com metadados."""
        return {
            **analysis,
            'metadata': {
                'input_bucket': s3_info['bucket'],
                'input_key': s3_info['key'],
                'processed_at': datetime.utcnow().isoformat(),
                'processor': 'text-processor-lambda',
                'version': '1.0'
            }
        }
    
    def _save_analysis_to_s3(self, analysis: Dict[str, Any], input_key: str) -> str:
        """Salva análise no S3 de output."""
        try:
            # Gerar chave do arquivo de output
            timestamp = datetime.utcnow().strftime('%Y%m%d-%H%M%S')
            filename = os.path.splitext(os.path.basename(input_key))[0]
            output_key = f"processed/{filename}-analysis-{timestamp}.json"
            
            # Converter análise para JSON
            analysis_json = json.dumps(analysis, indent=2, ensure_ascii=False)
            
            # Salvar no S3
            self.s3_client.put_object(
                Bucket=self.aws_config.output_bucket,
                Key=output_key,
                Body=analysis_json,
                ContentType='application/json'
            )
            
            logger.info(f"Análise salva em s3://{self.aws_config.output_bucket}/{output_key}")
            return output_key
            
        except Exception as e:
            raise Exception(f"Erro ao salvar análise no S3: {str(e)}")
    
    def _send_notification(self, analysis: Dict[str, Any], output_key: str):
        """Envia notificação SNS com resultado do processamento."""
        try:
            message = {
                'event': 'text_processing_completed',
                'timestamp': datetime.utcnow().isoformat(),
                'summary': {
                    'word_count': analysis['word_count'],
                    'char_count': analysis['char_count'],
                    'processing_time': analysis['processing_time']
                },
                'output_location': f"s3://{self.aws_config.output_bucket}/{output_key}",
                'input_file': analysis['metadata']['input_key']
            }
            
            self.sns_client.publish(
                TopicArn=self.aws_config.output_topic_arn,
                Message=json.dumps(message, indent=2),
                Subject='Processamento de Texto Concluído'
            )
            
            logger.info("Notificação SNS enviada com sucesso")
            
        except Exception as e:
            logger.warning(f"Erro ao enviar notificação SNS: {str(e)}")
            # Não falhar o processamento por causa da notificação