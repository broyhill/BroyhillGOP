#!/usr/bin/env python3
"""
BroyhillGOP Structured Logging System
Phase 2/3: Quality Improvements
"""
import json
import logging
import sys
from datetime import datetime
from typing import Dict, Any, Optional

class StructuredFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        log_data = {
            'timestamp': datetime.utcnow().isoformat(),
            'level': record.levelname,
            'logger': record.name,
            'message': record.getMessage(),
            'module': record.module,
            'function': record.funcName,
            'line': record.lineno
        }
        
        if hasattr(record, 'ecosystem'):
            log_data['ecosystem'] = record.ecosystem
        if hasattr(record, 'user_id'):
            log_data['user_id'] = record.user_id
        if hasattr(record, 'request_id'):
            log_data['request_id'] = record.request_id
        if hasattr(record, 'error_details'):
            log_data['error_details'] = record.error_details
        if record.exc_info:
            log_data['exception'] = self.formatException(record.exc_info)
            
        return json.dumps(log_data)

class EcosystemLogger:
    def __init__(self, ecosystem_name: str, log_level: int = logging.INFO):
        self.ecosystem_name = ecosystem_name
        self.logger = logging.getLogger(f'broyhillgop.{ecosystem_name}')
        self.logger.setLevel(log_level)
        
        if not self.logger.handlers:
            handler = logging.StreamHandler(sys.stdout)
            handler.setFormatter(StructuredFormatter())
            self.logger.addHandler(handler)
    
    def _log(self, level: int, message: str, extra: Dict = None):
        extra_data = {'ecosystem': self.ecosystem_name}
        if extra:
            extra_data.update(extra)
        self.logger.log(level, message, extra=extra_data)
    
    def info(self, message: str, **kwargs):
        self._log(logging.INFO, message, kwargs)
    
    def warning(self, message: str, **kwargs):
        self._log(logging.WARNING, message, kwargs)
    
    def error(self, message: str, **kwargs):
        self._log(logging.ERROR, message, kwargs)
    
    def debug(self, message: str, **kwargs):
        self._log(logging.DEBUG, message, kwargs)
    
    def critical(self, message: str, **kwargs):
        self._log(logging.CRITICAL, message, kwargs)

def get_ecosystem_logger(ecosystem_name: str) -> EcosystemLogger:
    return EcosystemLogger(ecosystem_name)

# Central logger for platform-wide events
platform_logger = EcosystemLogger('platform')
