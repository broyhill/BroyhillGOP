#!/usr/bin/env python3
"""
BroyhillGOP Circuit Breaker Implementation
Phase 2: Security & Stability - External Service Protection
"""
import time
from enum import Enum
from typing import Callable, Any, Optional
from functools import wraps
import threading

class CircuitState(Enum):
    CLOSED = 'closed'  # Normal operation
    OPEN = 'open'      # Failing, reject calls
    HALF_OPEN = 'half_open'  # Testing if service recovered

class CircuitBreaker:
    def __init__(self, failure_threshold: int = 5, recovery_timeout: int = 30, expected_exception: type = Exception):
        self.failure_threshold = failure_threshold
        self.recovery_timeout = recovery_timeout
        self.expected_exception = expected_exception
        self.failure_count = 0
        self.last_failure_time: Optional[float] = None
        self.state = CircuitState.CLOSED
        self._lock = threading.Lock()
        
    def __call__(self, func: Callable) -> Callable:
        @wraps(func)
        def wrapper(*args, **kwargs) -> Any:
            return self.call(func, *args, **kwargs)
        return wrapper
    
    def call(self, func: Callable, *args, **kwargs) -> Any:
        with self._lock:
            if self.state == CircuitState.OPEN:
                if self._should_attempt_reset():
                    self.state = CircuitState.HALF_OPEN
                else:
                    raise CircuitBreakerOpenError(f'Circuit breaker is OPEN for {func.__name__}')
        
        try:
            result = func(*args, **kwargs)
            self._on_success()
            return result
        except self.expected_exception as e:
            self._on_failure()
            raise
    
    def _should_attempt_reset(self) -> bool:
        return self.last_failure_time and (time.time() - self.last_failure_time) >= self.recovery_timeout
    
    def _on_success(self):
        with self._lock:
            self.failure_count = 0
            self.state = CircuitState.CLOSED
    
    def _on_failure(self):
        with self._lock:
            self.failure_count += 1
            self.last_failure_time = time.time()
            if self.failure_count >= self.failure_threshold:
                self.state = CircuitState.OPEN
    
    def get_state(self) -> CircuitState:
        return self.state
    
    def reset(self):
        with self._lock:
            self.failure_count = 0
            self.state = CircuitState.CLOSED
            self.last_failure_time = None

class CircuitBreakerOpenError(Exception):
    pass

# Pre-configured circuit breakers for common services
supabase_circuit = CircuitBreaker(failure_threshold=3, recovery_timeout=60)
ai_service_circuit = CircuitBreaker(failure_threshold=5, recovery_timeout=120)
external_api_circuit = CircuitBreaker(failure_threshold=5, recovery_timeout=30)
