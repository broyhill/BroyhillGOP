"""
shared/security/token_vault.py

AES-256-GCM token encryption helpers for Meta System User tokens.

Used by:
  - business_login_handler.py (encrypt newly-issued tokens before storage)
  - token_refresh_worker.py (decrypt for refresh API call, encrypt new token)
  - meta_api_client (decrypt for API calls)

Design:
  - AES-256-GCM via Python's cryptography library (authenticated encryption)
  - Key loaded from environment, never hardcoded, never logged
  - Key versioning supports rotation: stored alongside ciphertext
  - 12-byte random nonce per encryption (NIST recommendation for GCM)
  - Output format: nonce (12B) || ciphertext || GCM tag (16B), stored as BYTEA

Threat model addressed:
  - DB dump: ciphertext useless without key
  - Repeated-IV attack: random nonce per call
  - Tampering: GCM auth tag fails decryption if modified

NOT addressed (out of scope, host-level concerns):
  - Process memory dump while token is plaintext in RAM
  - Compromise of /opt/broyhillgop/config/.env on Hetzner
  - Privileged staff abusing platform_admin role

Phase: Step 5 of 8 in safe-pathway sequence. Dry-run only.
"""

from __future__ import annotations

import base64
import logging
import os
import re
from dataclasses import dataclass
from typing import Optional

from cryptography.hazmat.primitives.ciphers.aead import AESGCM


logger = logging.getLogger("e19_social.security.token_vault")


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

# Environment variable names. Keys live in /opt/broyhillgop/config/.env on Hetzner.
# Format: META_TOKEN_KEY_<KEY_ID>=<base64-encoded 32 bytes>
# Example: META_TOKEN_KEY_v1=hXk2fJ...base64-32-bytes...
ENV_KEY_PREFIX = "META_TOKEN_KEY_"
ENV_ACTIVE_KEY_ID = "META_TOKEN_ACTIVE_KEY_ID"  # Tells encryptor which key to use for new encryptions

# GCM nonce size. 12 bytes is NIST-recommended.
NONCE_SIZE = 12


# ---------------------------------------------------------------------------
# Errors
# ---------------------------------------------------------------------------

class TokenVaultError(Exception):
    """Base class for vault errors."""


class MissingKeyError(TokenVaultError):
    """The requested encryption key is not loaded."""


class DecryptionFailedError(TokenVaultError):
    """Decryption failed — likely tampering or wrong key."""


class KeyConfigurationError(TokenVaultError):
    """Environment is missing required key configuration."""


# ---------------------------------------------------------------------------
# Key management
# ---------------------------------------------------------------------------

@dataclass(frozen=True)
class _LoadedKey:
    key_id: str
    key_bytes: bytes  # 32 bytes for AES-256


def _load_keys_from_env() -> dict[str, _LoadedKey]:
    """
    Scan os.environ for META_TOKEN_KEY_* entries and return them.
    Returns dict keyed by key_id. Empty dict if no keys configured.
    """
    keys: dict[str, _LoadedKey] = {}
    for env_name, value in os.environ.items():
        if not env_name.startswith(ENV_KEY_PREFIX):
            continue
        key_id = env_name[len(ENV_KEY_PREFIX):]
        if not key_id:
            continue
        try:
            key_bytes = base64.b64decode(value)
        except Exception as exc:
            raise KeyConfigurationError(
                f"{env_name} is not valid base64"
            ) from exc
        if len(key_bytes) != 32:
            raise KeyConfigurationError(
                f"{env_name} must decode to exactly 32 bytes for AES-256, got {len(key_bytes)}"
            )
        keys[key_id] = _LoadedKey(key_id=key_id, key_bytes=key_bytes)
    return keys


def _get_active_key_id() -> str:
    active = os.environ.get(ENV_ACTIVE_KEY_ID)
    if not active:
        raise KeyConfigurationError(
            f"{ENV_ACTIVE_KEY_ID} not set. "
            f"Set it to the key_id (e.g. 'v1') to use for new encryptions."
        )
    return active


# Lazy-loaded singleton. Re-loaded on demand if env changes (e.g. after rotation).
_loaded_keys: Optional[dict[str, _LoadedKey]] = None


def _keys() -> dict[str, _LoadedKey]:
    global _loaded_keys
    if _loaded_keys is None:
        _loaded_keys = _load_keys_from_env()
    return _loaded_keys


def reload_keys() -> None:
    """
    Force re-load of keys from environment.
    Call after key rotation when a new META_TOKEN_KEY_<id> has been added to env.
    Test code may also call this between tests.
    """
    global _loaded_keys
    _loaded_keys = None


# ---------------------------------------------------------------------------
# Encrypt / Decrypt
# ---------------------------------------------------------------------------

def encrypt_token(plaintext_token: str) -> tuple[bytes, str]:
    """
    Encrypt a plaintext Meta access token.

    Returns:
        (ciphertext_bytes, key_id_used)
        ciphertext_bytes is suitable for INSERT into BYTEA column.
        key_id_used should be stored in meta_encryption_key_id column.

    Raises:
        KeyConfigurationError: if no active key configured
        MissingKeyError: if active key id refers to a key not in env
    """
    if not isinstance(plaintext_token, str):
        raise TypeError("plaintext_token must be str")
    if not plaintext_token:
        raise ValueError("plaintext_token must be non-empty")

    active_key_id = _get_active_key_id()
    keys = _keys()
    if active_key_id not in keys:
        raise MissingKeyError(
            f"Active key '{active_key_id}' not loaded. "
            f"Verify {ENV_KEY_PREFIX}{active_key_id} is set in env."
        )

    aesgcm = AESGCM(keys[active_key_id].key_bytes)
    nonce = os.urandom(NONCE_SIZE)
    ciphertext = aesgcm.encrypt(nonce, plaintext_token.encode("utf-8"), associated_data=None)
    # Store as: nonce || ciphertext_with_tag
    blob = nonce + ciphertext
    return blob, active_key_id


def decrypt_token(blob: bytes, key_id: str) -> str:
    """
    Decrypt a token blob produced by encrypt_token().

    Args:
        blob: bytes from BYTEA column
        key_id: value from meta_encryption_key_id column

    Returns:
        plaintext token

    Raises:
        MissingKeyError: if the key referenced by key_id isn't loaded
        DecryptionFailedError: if decryption fails (tampering, corruption, wrong key)
    """
    if not isinstance(blob, (bytes, bytearray, memoryview)):
        raise TypeError("blob must be bytes-like")
    if len(blob) < NONCE_SIZE + 16:  # Need at least nonce + GCM tag
        raise DecryptionFailedError("blob too short to be a valid encrypted token")
    if not key_id:
        raise ValueError("key_id is required")

    keys = _keys()
    if key_id not in keys:
        raise MissingKeyError(
            f"Key '{key_id}' not loaded. "
            f"This token was encrypted with a key no longer in env. "
            f"If keys were rotated, ensure old keys remain loaded for decryption."
        )

    blob_bytes = bytes(blob)
    nonce = blob_bytes[:NONCE_SIZE]
    ciphertext = blob_bytes[NONCE_SIZE:]

    aesgcm = AESGCM(keys[key_id].key_bytes)
    try:
        plaintext = aesgcm.decrypt(nonce, ciphertext, associated_data=None)
    except Exception as exc:
        raise DecryptionFailedError(
            "GCM decryption failed. Token may be tampered, corrupted, or encrypted with a different key."
        ) from exc

    return plaintext.decode("utf-8")


# ---------------------------------------------------------------------------
# Logging redaction
# ---------------------------------------------------------------------------

# Meta access tokens are typically alphanumeric with EAA prefix and ~200+ chars.
# Catch a few common patterns to redact from logs.
_TOKEN_PATTERNS = [
    re.compile(r"\bEAA[A-Za-z0-9_-]{50,}", re.IGNORECASE),       # Meta long-lived tokens
    re.compile(r"\baccess_token=[A-Za-z0-9_-]+", re.IGNORECASE), # URL-form tokens
    re.compile(r"\b[A-Za-z0-9_-]{200,}"),                        # Any 200+ char token-shaped string
]


def redact_tokens(text: str) -> str:
    """
    Redact anything that looks like a Meta token from a log string.
    Defense-in-depth — application code should never log tokens directly,
    but this catches accidental leaks.
    """
    if not text:
        return text
    for pat in _TOKEN_PATTERNS:
        text = pat.sub("[REDACTED_TOKEN]", text)
    return text


class RedactingFormatter(logging.Formatter):
    """
    Logging formatter that redacts token-shaped strings.
    Wire into the application's root logger to catch accidental logging.
    """
    def format(self, record: logging.LogRecord) -> str:
        formatted = super().format(record)
        return redact_tokens(formatted)


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

def _self_test() -> bool:
    """
    Verify encrypt/decrypt round-trip works with currently loaded keys.
    Returns True on success. Used by health checks.
    """
    try:
        sample = "EAA_test_token_for_self_test_" + "x" * 64
        blob, key_id = encrypt_token(sample)
        roundtripped = decrypt_token(blob, key_id)
        return roundtripped == sample
    except Exception:
        logger.exception("token_vault self-test failed")
        return False


__all__ = [
    "encrypt_token",
    "decrypt_token",
    "redact_tokens",
    "RedactingFormatter",
    "reload_keys",
    "TokenVaultError",
    "MissingKeyError",
    "DecryptionFailedError",
    "KeyConfigurationError",
]
