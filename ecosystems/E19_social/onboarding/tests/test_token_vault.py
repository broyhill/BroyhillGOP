"""
ecosystems/E19_social/onboarding/tests/test_token_vault.py

Tests for shared/security/token_vault.py.

Run with: pytest ecosystems/E19_social/onboarding/tests/test_token_vault.py
"""

from __future__ import annotations

import base64
import os
import pytest

from shared.security import token_vault
from shared.security.token_vault import (
    encrypt_token,
    decrypt_token,
    redact_tokens,
    reload_keys,
    DecryptionFailedError,
    MissingKeyError,
    KeyConfigurationError,
)


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def _clean_env(monkeypatch):
    """Strip any META_TOKEN_KEY_* from env between tests."""
    for var in list(os.environ.keys()):
        if var.startswith("META_TOKEN_KEY_") or var == "META_TOKEN_ACTIVE_KEY_ID":
            monkeypatch.delenv(var, raising=False)
    reload_keys()
    yield
    reload_keys()


def _set_key(monkeypatch, key_id: str, key_bytes: bytes, active: bool = False) -> None:
    encoded = base64.b64encode(key_bytes).decode("ascii")
    monkeypatch.setenv(f"META_TOKEN_KEY_{key_id}", encoded)
    if active:
        monkeypatch.setenv("META_TOKEN_ACTIVE_KEY_ID", key_id)
    reload_keys()


# ---------------------------------------------------------------------------
# Round-trip
# ---------------------------------------------------------------------------

class TestRoundTrip:
    def test_encrypt_decrypt_roundtrip(self, monkeypatch):
        _set_key(monkeypatch, "v1", os.urandom(32), active=True)
        original = "EAA_some_meta_token_string_123"
        blob, key_id = encrypt_token(original)
        assert key_id == "v1"
        assert blob != original.encode()
        assert isinstance(blob, bytes)
        recovered = decrypt_token(blob, key_id)
        assert recovered == original

    def test_each_encryption_produces_different_ciphertext(self, monkeypatch):
        """Random nonce ensures repeated encryptions of the same plaintext differ."""
        _set_key(monkeypatch, "v1", os.urandom(32), active=True)
        plain = "same_token"
        blob1, _ = encrypt_token(plain)
        blob2, _ = encrypt_token(plain)
        assert blob1 != blob2
        # Both still decrypt to the same plaintext
        assert decrypt_token(blob1, "v1") == plain
        assert decrypt_token(blob2, "v1") == plain

    def test_long_token(self, monkeypatch):
        _set_key(monkeypatch, "v1", os.urandom(32), active=True)
        plain = "x" * 5000
        blob, key_id = encrypt_token(plain)
        assert decrypt_token(blob, key_id) == plain

    def test_unicode_token(self, monkeypatch):
        _set_key(monkeypatch, "v1", os.urandom(32), active=True)
        plain = "EAA_token_with_emojis_🔒_and_unicode_ü"
        blob, key_id = encrypt_token(plain)
        assert decrypt_token(blob, key_id) == plain


# ---------------------------------------------------------------------------
# Configuration errors
# ---------------------------------------------------------------------------

class TestConfiguration:
    def test_no_active_key_set(self, monkeypatch):
        with pytest.raises(KeyConfigurationError, match="META_TOKEN_ACTIVE_KEY_ID"):
            encrypt_token("anything")

    def test_active_key_not_loaded(self, monkeypatch):
        # Set active key id but don't define the key
        monkeypatch.setenv("META_TOKEN_ACTIVE_KEY_ID", "missing")
        reload_keys()
        with pytest.raises(MissingKeyError, match="missing"):
            encrypt_token("anything")

    def test_invalid_base64_key(self, monkeypatch):
        monkeypatch.setenv("META_TOKEN_KEY_v1", "not!!!base64@@@")
        monkeypatch.setenv("META_TOKEN_ACTIVE_KEY_ID", "v1")
        reload_keys()
        with pytest.raises(KeyConfigurationError, match="not valid base64"):
            encrypt_token("anything")

    def test_wrong_size_key(self, monkeypatch):
        # 16-byte key (AES-128) — we require AES-256 (32 bytes)
        bad = base64.b64encode(os.urandom(16)).decode("ascii")
        monkeypatch.setenv("META_TOKEN_KEY_v1", bad)
        monkeypatch.setenv("META_TOKEN_ACTIVE_KEY_ID", "v1")
        reload_keys()
        with pytest.raises(KeyConfigurationError, match="32 bytes"):
            encrypt_token("anything")


# ---------------------------------------------------------------------------
# Tampering / corruption
# ---------------------------------------------------------------------------

class TestTampering:
    def test_modified_ciphertext_fails(self, monkeypatch):
        _set_key(monkeypatch, "v1", os.urandom(32), active=True)
        blob, key_id = encrypt_token("important_token")
        # Flip a byte in the ciphertext (after the 12-byte nonce)
        tampered = bytearray(blob)
        tampered[20] ^= 0xFF
        with pytest.raises(DecryptionFailedError):
            decrypt_token(bytes(tampered), key_id)

    def test_truncated_blob_fails(self, monkeypatch):
        _set_key(monkeypatch, "v1", os.urandom(32), active=True)
        with pytest.raises(DecryptionFailedError, match="too short"):
            decrypt_token(b"short", "v1")

    def test_wrong_key_fails(self, monkeypatch):
        # Encrypt with v1, attempt to decrypt with v2 (different key, same key_id label)
        key_a = os.urandom(32)
        key_b = os.urandom(32)
        _set_key(monkeypatch, "v1", key_a, active=True)
        blob, _ = encrypt_token("token")
        # Now switch v1 to point at a different key
        encoded_b = base64.b64encode(key_b).decode("ascii")
        monkeypatch.setenv("META_TOKEN_KEY_v1", encoded_b)
        reload_keys()
        with pytest.raises(DecryptionFailedError):
            decrypt_token(blob, "v1")


# ---------------------------------------------------------------------------
# Key rotation
# ---------------------------------------------------------------------------

class TestKeyRotation:
    def test_old_tokens_decryptable_after_rotation(self, monkeypatch):
        # Issue token under v1
        _set_key(monkeypatch, "v1", os.urandom(32), active=True)
        old_blob, old_key_id = encrypt_token("old_token")
        assert old_key_id == "v1"

        # Rotate: v2 becomes active, v1 remains loaded for decryption
        _set_key(monkeypatch, "v2", os.urandom(32), active=True)
        # Re-add v1 since _set_key didn't clear it (we only set new active)
        # Actually _clean_env strips at fixture teardown, but within test the env retains v1.
        # Verify by re-reading
        assert "META_TOKEN_KEY_v1" in os.environ
        reload_keys()

        # Old token still decrypts
        recovered = decrypt_token(old_blob, "v1")
        assert recovered == "old_token"

        # New encryptions use v2
        new_blob, new_key_id = encrypt_token("new_token")
        assert new_key_id == "v2"
        assert decrypt_token(new_blob, "v2") == "new_token"

    def test_decrypt_fails_if_old_key_removed(self, monkeypatch):
        # Encrypt under v1
        _set_key(monkeypatch, "v1", os.urandom(32), active=True)
        blob, key_id = encrypt_token("token")

        # Remove v1 entirely (rotation went too far)
        monkeypatch.delenv("META_TOKEN_KEY_v1")
        reload_keys()

        with pytest.raises(MissingKeyError, match="v1"):
            decrypt_token(blob, key_id)


# ---------------------------------------------------------------------------
# Redaction
# ---------------------------------------------------------------------------

class TestRedaction:
    def test_redacts_eaa_token(self):
        text = "log line with token EAAabc123" + ("x" * 60) + " end"
        redacted = redact_tokens(text)
        assert "[REDACTED_TOKEN]" in redacted
        assert "EAAabc" not in redacted

    def test_redacts_url_form_token(self):
        text = "url with access_token=EAA12345abcdef and other params"
        redacted = redact_tokens(text)
        assert "EAA12345abcdef" not in redacted
        assert "[REDACTED_TOKEN]" in redacted

    def test_redacts_long_alphanumeric_string(self):
        long_string = "a" * 250
        text = f"some log line {long_string} more content"
        redacted = redact_tokens(text)
        assert long_string not in redacted

    def test_short_strings_not_redacted(self):
        text = "ordinary log line with short_id_abc123"
        redacted = redact_tokens(text)
        assert redacted == text

    def test_empty_string_safe(self):
        assert redact_tokens("") == ""
        assert redact_tokens(None) is None  # type: ignore


# ---------------------------------------------------------------------------
# Self-test
# ---------------------------------------------------------------------------

class TestSelfTest:
    def test_self_test_passes_with_valid_config(self, monkeypatch):
        _set_key(monkeypatch, "v1", os.urandom(32), active=True)
        assert token_vault._self_test() is True

    def test_self_test_fails_without_config(self, monkeypatch):
        # No keys set
        assert token_vault._self_test() is False
