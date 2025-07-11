import logging
import os
import sys
from typing import Optional


def setup_logger(name: Optional[str] = None, level: str = 'INFO') -> logging.Logger:
    """
    Configura logger para a Lambda.
    
    Args:
        name: Nome do logger (padrão: nome do módulo)
        level: Nível de log (DEBUG, INFO, WARNING, ERROR)
        
    Returns:
        Logger configurado
    """
    # Usar nome do módulo se não especificado
    if name is None:
        name = __name__
    
    logger = logging.getLogger(name)
    
    # Evitar duplicação de handlers
    if logger.handlers:
        return logger
    
    # Configurar nível
    log_level = getattr(logging, level.upper(), logging.INFO)
    logger.setLevel(log_level)
    
    # Configurar handler
    handler = logging.StreamHandler(sys.stdout)
    handler.setLevel(log_level)
    
    # Configurar formato
    formatter = logging.Formatter(
        '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
    )
    handler.setFormatter(formatter)
    
    # Adicionar handler ao logger
    logger.addHandler(handler)
    
    # Configurar nível baseado em variável de ambiente
    env_level = os.getenv('LOG_LEVEL', 'INFO').upper()
    if env_level in ['DEBUG', 'INFO', 'WARNING', 'ERROR']:
        logger.setLevel(getattr(logging, env_level))
    
    return logger


def get_lambda_logger() -> logging.Logger:
    """
    Retorna logger específico para Lambda.
    
    Returns:
        Logger configurado para Lambda
    """
    return setup_logger('lambda_function', 'INFO')


def log_event(logger: logging.Logger, event: dict, context=None):
    """
    Log padronizado para eventos Lambda.
    
    Args:
        logger: Logger a ser usado
        event: Evento da Lambda
        context: Contexto da Lambda
    """
    logger.info("=== INÍCIO DO PROCESSAMENTO ===")
    logger.info(f"Event: {event}")
    
    if context:
        logger.info(f"Context: {context}")
        logger.info(f"Request ID: {context.aws_request_id}")
        logger.info(f"Remaining time: {context.get_remaining_time_in_millis()}ms")
    
    logger.info("=== FIM DO LOG DE EVENTO ===")


def log_result(logger: logging.Logger, result: dict):
    """
    Log padronizado para resultados Lambda.
    
    Args:
        logger: Logger a ser usado
        result: Resultado do processamento
    """
    logger.info("=== RESULTADO DO PROCESSAMENTO ===")
    logger.info(f"Status: {result.get('statusCode', 'N/A')}")
    logger.info(f"Result: {result}")
    logger.info("=== FIM DO PROCESSAMENTO ===")


def log_error(logger: logging.Logger, error: Exception, context: str = ""):
    """
    Log padronizado para erros.
    
    Args:
        logger: Logger a ser usado
        error: Exceção capturada
        context: Contexto adicional sobre o erro
    """
    logger.error("=== ERRO CAPTURADO ===")
    if context:
        logger.error(f"Contexto: {context}")
    logger.error(f"Tipo: {type(error).__name__}")
    logger.error(f"Mensagem: {str(error)}")
    logger.error("=== FIM DO LOG DE ERRO ===")
    
    # Log do stack trace em debug
    logger.debug("Stack trace:", exc_info=True)