#!/usr/bin/env python3
"""
BroyhillGOP Centralized Authentication Service
Phase 2: Security & Stability Implementation
"""
import os
import jwt
import hashlib
import secrets
from datetime import datetime, timedelta
from typing import Optional, Dict, Any
from functools import wraps

class AuthConfig:
    SECRET_KEY = os.getenv('BROYHILLGOP_SECRET_KEY', secrets.token_hex(32))
    ALGORITHM = 'HS256'
    ACCESS_TOKEN_EXPIRE_MINUTES = 30
    REFRESH_TOKEN_EXPIRE_DAYS = 7
    
class AuthService:
    def __init__(self, config: AuthConfig = None):
        self.config = config or AuthConfig()
        
    def create_access_token(self, data: Dict[str, Any], expires_delta: Optional[timedelta] = None) -> str:
        to_encode = data.copy()
        expire = datetime.utcnow() + (expires_delta or timedelta(minutes=self.config.ACCESS_TOKEN_EXPIRE_MINUTES))
        to_encode.update({'exp': expire, 'type': 'access'})
        return jwt.encode(to_encode, self.config.SECRET_KEY, algorithm=self.config.ALGORITHM)
    
    def create_refresh_token(self, data: Dict[str, Any]) -> str:
        to_encode = data.copy()
        expire = datetime.utcnow() + timedelta(days=self.config.REFRESH_TOKEN_EXPIRE_DAYS)
        to_encode.update({'exp': expire, 'type': 'refresh'})
        return jwt.encode(to_encode, self.config.SECRET_KEY, algorithm=self.config.ALGORITHM)
    
    def verify_token(self, token: str) -> Optional[Dict[str, Any]]:
        try:
            payload = jwt.decode(token, self.config.SECRET_KEY, algorithms=[self.config.ALGORITHM])
            return payload
        except jwt.ExpiredSignatureError:
            return None
        except jwt.InvalidTokenError:
            return None
    
    def hash_password(self, password: str) -> str:
        salt = secrets.token_hex(16)
        hashed = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
        return f"{salt}:{hashed.hex()}"
    
    def verify_password(self, password: str, hashed: str) -> bool:
        try:
            salt, stored_hash = hashed.split(':')
            new_hash = hashlib.pbkdf2_hmac('sha256', password.encode(), salt.encode(), 100000)
            return new_hash.hex() == stored_hash
        except:
            return False

def require_auth(func):
    @wraps(func)
    def wrapper(*args, **kwargs):
        auth_service = AuthService()
        token = kwargs.get('token') or (args[0] if args else None)
        if not token or not auth_service.verify_token(token):
            raise PermissionError('Authentication required')
        return func(*args, **kwargs)
    return wrapper

auth_service = AuthService()
