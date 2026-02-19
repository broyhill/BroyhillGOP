#!/usr/bin/env python3
"""
BroyhillGOP Comprehensive Error Handling Framework
Phase 2: Security & Stability Implementation
"""
import logging
import traceback
from datetime import datetime
from typing import Optional, Dict, Any, Callable
from functools import wraps
from enum import Enum

class ErrorSeverity(Enum):
    LOW = 'low'
    MEDIUM = 'medium'
    HIGH = 'high'
    CRITICAL = 'critical'

class BroyhillGOPException(Exception):
    def __init__(self, message: str, code: str = 'UNKNOWN', severity: ErrorSeverity = ErrorSeverity.MEDIUM, details: Dict = None):
        super().__init__(message)
        self.message = message
        self.code = code
        self.severity = severity
        self.details = details or {}
        self.timestamp = datetime.utcnow().isoformat()
        
    def to_dict(self) -> Dict[str, Any]:
        return {
            'error': self.message,
            'code': self.code,
            'severity': self.severity.value,
            'details': self.details,
            'timestamp': self.timestamp
        }

class DatabaseError(BroyhillGOPException):
    def __init__(self, message: str, details: Dict = None):
        super().__init__(message, 'DB_ERROR', ErrorSeverity.HIGH, details)

class AuthenticationError(BroyhillGOPException):
    def __init__(self, message: str, details: Dict = None):
        super().__init__(message, 'AUTH_ERROR', ErrorSeverity.HIGH, details)

class ValidationError(BroyhillGOPException):
    def __init__(self, message: str, details: Dict = None):
        super().__init__(message, 'VALIDATION_ERROR', ErrorSeverity.LOW, details)

class ExternalServiceError(BroyhillGOPException):
    def __init__(self, message: str, service_name: str, details: Dict = None):
        super().__init__(message, f'EXT_SERVICE_{service_name.upper()}', ErrorSeverity.MEDIUM, details)
        self.service_name = service_name

class ErrorHandler:
    def __init__(self, logger: logging.Logger = None):
        self.logger = logger or logging.getLogger('broyhillgop')
        self.error_callbacks = []
        
    def add_callback(self, callback: Callable[[BroyhillGOPException], None]):
        self.error_callbacks.append(callback)
        
    def handle(self, error: Exception, context: Dict = None) -> Dict[str, Any]:
        if isinstance(error, BroyhillGOPException):
            result = error.to_dict()
            if context:
                result['context'] = context
        else:
            result = {
                'error': str(error),
                'code': 'UNHANDLED_ERROR',
                'severity': ErrorSeverity.HIGH.value,
                'traceback': traceback.format_exc(),
                'timestamp': datetime.utcnow().isoformat()
            }
        
        self.logger.error(f"[{result['code']}] {result['error']}", extra={'error_details': result})
        
        for callback in self.error_callbacks:
            try:
                callback(error)
            except:
                pass
        
        return result

def with_error_handling(handler: ErrorHandler = None):
    def decorator(func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs):
            try:
                return func(*args, **kwargs)
            except Exception as e:
                h = handler or ErrorHandler()
                return {'success': False, **h.handle(e, {'function': func.__name__})}
        return wrapper
    return decorator

error_handler = ErrorHandler()
