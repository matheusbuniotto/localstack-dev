import os
import boto3
from typing import Optional


class AWSConfig:
    """
    Configuração centralizada para serviços AWS.
    Suporta tanto LocalStack quanto AWS real.
    """
    
    def __init__(self):
        # Configurações básicas
        self.region = os.getenv('AWS_DEFAULT_REGION', 'us-east-1')
        
        # Configuração do endpoint para LocalStack
        # Dentro da Lambda, usar o endpoint interno do LocalStack
        self.endpoint_url = os.getenv('AWS_ENDPOINT_URL')
        
        # Se estiver rodando na Lambda dentro do LocalStack, usar endpoint interno
        if self.endpoint_url and 'localhost' in self.endpoint_url:
            # Dentro do LocalStack, usar endpoint interno
            self.endpoint_url = self.endpoint_url.replace('localhost', 'localstack')
        
        # Fallback para LocalStack host padrão se não definido
        if not self.endpoint_url:
            self.endpoint_url = 'http://localstack:4566'
        
        # Recursos AWS
        self.input_bucket = os.getenv('S3_INPUT_BUCKET', 'input-bucket')
        self.output_bucket = os.getenv('S3_OUTPUT_BUCKET', 'output-bucket')
        self.input_topic_arn = os.getenv('SNS_INPUT_TOPIC_ARN', 'arn:aws:sns:us-east-1:000000000000:input-topic')
        self.output_topic_arn = os.getenv('SNS_OUTPUT_TOPIC_ARN', 'arn:aws:sns:us-east-1:000000000000:output-topic')
        
        # Configurações de cliente
        self.client_config = {
            'region_name': self.region,
            'endpoint_url': self.endpoint_url
        }
        
        # Log da configuração
        self._log_configuration()
    
    def get_s3_client(self):
        """Retorna cliente S3 configurado."""
        return boto3.client('s3', **self.client_config)
    
    def get_sns_client(self):
        """Retorna cliente SNS configurado."""
        return boto3.client('sns', **self.client_config)
    
    def get_sqs_client(self):
        """Retorna cliente SQS configurado."""
        return boto3.client('sqs', **self.client_config)
    
    def get_secrets_client(self):
        """Retorna cliente Secrets Manager configurado."""
        return boto3.client('secretsmanager', **self.client_config)
    
    def is_localstack(self) -> bool:
        """Verifica se está rodando no LocalStack."""
        return self.endpoint_url is not None
    
    def get_environment(self) -> str:
        """Retorna ambiente atual."""
        return "localstack" if self.is_localstack() else "aws"
    
    def _log_configuration(self):
        """Log da configuração atual."""
        import logging
        logger = logging.getLogger(__name__)
        
        logger.info(f"AWS Config inicializada:")
        logger.info(f"  Ambiente: {self.get_environment()}")
        logger.info(f"  Região: {self.region}")
        logger.info(f"  Endpoint: {self.endpoint_url or 'AWS padrão'}")
        logger.info(f"  Input Bucket: {self.input_bucket}")
        logger.info(f"  Output Bucket: {self.output_bucket}")
    
    def validate_configuration(self) -> bool:
        """
        Valida se a configuração está correta.
        
        Returns:
            True se configuração válida, False caso contrário
        """
        try:
            # Testar conexão S3
            s3_client = self.get_s3_client()
            s3_client.head_bucket(Bucket=self.input_bucket)
            
            # Testar conexão SNS
            sns_client = self.get_sns_client()
            sns_client.get_topic_attributes(TopicArn=self.output_topic_arn)
            
            return True
            
        except Exception as e:
            import logging
            logger = logging.getLogger(__name__)
            logger.error(f"Erro na validação da configuração AWS: {str(e)}")
            return False