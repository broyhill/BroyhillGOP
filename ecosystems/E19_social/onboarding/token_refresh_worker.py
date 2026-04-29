"""
ecosystems/E19_social/onboarding/token_refresh_worker.py

Daily cron worker that refreshes Meta System User tokens before they expire.

Meta long-lived tokens last ~60 days. We refresh tokens that:
  - Belong to a candidate in 'provisioned' status
  - Have an encrypted token on file
  - Expire within the next 7 days
  - Have not been refreshed in the last 24 hours

For each candidate, we:
  1. Decrypt current token
  2. Call Meta's refresh endpoint
  3. Encrypt new token, update candidate_social_accounts
  4. Log attempt to meta_token_refresh_attempts
  5. On persistent failure (3+ in a row), mark status oauth_expired and alert staff

Designed to be:
  - Idempotent (safe to run multiple times per day)
  - Fault-tolerant (one candidate's failure doesn't stop the worker)
  - Observable (every attempt logged with outcome)
  - Rate-limited (avoid hammering Meta's API)

Phase: Step 5 of 8. Dry-run only.
"""

from __future__ import annotations

import logging
import os
import time
from dataclasses import dataclass
from datetime import datetime, timedelta
from typing import Optional
from uuid import UUID

import requests

from shared.security.token_vault import (
    encrypt_token,
    decrypt_token,
    redact_tokens,
    DecryptionFailedError,
    MissingKeyError,
)
from shared.event_bus import EventPublisher, NullEventPublisher
from shared.brain_control.governance import (
    SelfCorrectionReader,
    NullSelfCorrectionReader,
    CostAccountant,
    NullCostAccountant,
    HealthReporter,
    NullHealthReporter,
    HealthSnapshot,
    FunctionCallRecord,
    is_paused,
)


logger = logging.getLogger("e19_social.onboarding.token_refresh_worker")


# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

META_GRAPH_VERSION = os.environ.get("META_GRAPH_API_VERSION", "v19.0")
META_GRAPH_BASE = f"https://graph.facebook.com/{META_GRAPH_VERSION}"

FACEBOOK_APP_ID = os.environ.get("FACEBOOK_APP_ID", "")
FACEBOOK_APP_SECRET = os.environ.get("FACEBOOK_APP_SECRET", "")

# Refresh policy
REFRESH_WINDOW_DAYS = 7      # Refresh tokens within N days of expiry
MIN_HOURS_BETWEEN_ATTEMPTS = 24
MAX_CONSECUTIVE_FAILURES = 3
PER_REQUEST_TIMEOUT = 30
RATE_LIMIT_PAUSE_SECONDS = 1.0  # Pause between candidates to avoid Meta rate limits

LONG_LIVED_TOKEN_DURATION_DAYS = 60


# ---------------------------------------------------------------------------
# Data classes
# ---------------------------------------------------------------------------

@dataclass
class RefreshCandidate:
    """A row from v_meta_tokens_needing_refresh."""
    candidate_id: UUID
    business_manager_id: str
    system_user_id: str
    system_user_token_expires_at: datetime
    days_until_expiry: int


@dataclass
class RefreshOutcome:
    candidate_id: UUID
    outcome: str
    error_code: Optional[str] = None
    error_message: Optional[str] = None
    new_expires_at: Optional[datetime] = None


# ---------------------------------------------------------------------------
# Database access (abstract)
# ---------------------------------------------------------------------------

class RefreshStore:
    """Persistence layer the worker depends on. Concrete impl wraps psycopg2."""

    def list_candidates_needing_refresh(self) -> list[RefreshCandidate]:
        """Return rows from v_meta_tokens_needing_refresh view."""
        raise NotImplementedError

    def read_encrypted_token(
        self, candidate_id: UUID
    ) -> tuple[bytes, str]:
        """
        Return (token_blob, key_id) for this candidate's current System User token.
        Raises if no token on file.
        """
        raise NotImplementedError

    def write_refreshed_token(
        self,
        *,
        candidate_id: UUID,
        token_blob: bytes,
        key_id: str,
        expires_at: datetime,
    ) -> None:
        """Update candidate_social_accounts with new encrypted token + expiry + last_token_refresh_at."""
        raise NotImplementedError

    def log_attempt(
        self,
        *,
        candidate_id: UUID,
        outcome: str,
        error_code: Optional[str] = None,
        error_message: Optional[str] = None,
        new_expires_at: Optional[datetime] = None,
    ) -> None:
        """Append row to meta_token_refresh_attempts."""
        raise NotImplementedError

    def consecutive_failure_count(self, candidate_id: UUID) -> int:
        """How many failed attempts in a row for this candidate (0 if last attempt was success)."""
        raise NotImplementedError

    def mark_expired(self, candidate_id: UUID) -> None:
        """Set bm_provisioning_status to 'oauth_expired' on candidate_social_accounts."""
        raise NotImplementedError


class StaffNotifier:
    """Out-of-band notification for staff alerts (email/Slack/etc)."""

    def alert_token_expired(self, candidate_id: UUID, error_message: str) -> None:
        raise NotImplementedError


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

def run_refresh_pass(
    *,
    store: RefreshStore,
    notifier: Optional[StaffNotifier] = None,
    rate_limit_pause: float = RATE_LIMIT_PAUSE_SECONDS,
    publisher: Optional[EventPublisher] = None,
    cost_accountant: Optional[CostAccountant] = None,
    health_reporter: Optional[HealthReporter] = None,
    self_correction: Optional[SelfCorrectionReader] = None,
) -> dict:
    """
    Run one pass of the refresh worker.

    Brain integration:
      - Publishes social.token.refreshed / social.token.refresh_failed / social.token.expired
      - Records F902 cost accounting
      - Reports health snapshot to brain_control at end of pass
      - Honors app-wide pause from brain_control (skips entire pass if paused)

    Returns a summary dict:
        {
          'total': N, 'succeeded': N, 'failed': N, 'expired': N,
          'rate_limited': N, 'paused': bool, 'errors': [...]
        }
    """
    pub = publisher or NullEventPublisher()
    accountant = cost_accountant or NullCostAccountant()
    health = health_reporter or NullHealthReporter()
    corrector = self_correction or NullSelfCorrectionReader()

    summary = {
        "total": 0,
        "succeeded": 0,
        "failed": 0,
        "expired": 0,
        "rate_limited": 0,
        "paused": False,
        "errors": [],
    }

    # Honor app-wide pause: skip the entire pass if Brain has paused automation
    if corrector.get_app_wide().directive.value == "paused":
        logger.info("refresh pass skipped: app-wide automation paused by Brain")
        summary["paused"] = True
        health.report(HealthSnapshot(
            ecosystem_code="E19_TECH_PROVIDER",
            status="MAINTENANCE",
            error_count=0,
        ))
        return summary

    queue = store.list_candidates_needing_refresh()
    summary["total"] = len(queue)
    logger.info("refresh pass starting: %d candidate(s) due for refresh", len(queue))

    pass_start = datetime.utcnow()
    for candidate in queue:
        # Per-candidate pause: skip individual candidate without aborting the pass
        if is_paused(corrector, candidate_id=str(candidate.candidate_id)):
            logger.debug("skipping candidate=%s: paused by Brain", candidate.candidate_id)
            continue

        outcome = _refresh_one(candidate, store, notifier)
        store.log_attempt(
            candidate_id=outcome.candidate_id,
            outcome=outcome.outcome,
            error_code=outcome.error_code,
            error_message=outcome.error_message,
            new_expires_at=outcome.new_expires_at,
        )

        # Cost accounting per attempt
        accountant.record_call(FunctionCallRecord(
            function_code="F902",
            candidate_id=str(outcome.candidate_id),
            success=(outcome.outcome == "success"),
            error_type=outcome.outcome if outcome.outcome != "success" else None,
        ))

        if outcome.outcome == "success":
            summary["succeeded"] += 1
            pub.publish(
                "social.token.refreshed",
                candidate_id=outcome.candidate_id,
                payload={
                    "new_expires_at": outcome.new_expires_at.isoformat() if outcome.new_expires_at else None,
                },
            )
        elif outcome.outcome == "rate_limited":
            summary["rate_limited"] += 1
            # Stop the pass if we hit rate limits — don't make it worse
            logger.warning("rate limit hit; aborting refresh pass early at candidate=%s", outcome.candidate_id)
            pub.publish(
                "social.app_health.degraded",
                candidate_id=None,
                payload={"reason": "rate_limit", "halted_pass_at": str(outcome.candidate_id)},
            )
            break
        else:
            summary["failed"] += 1
            summary["errors"].append((outcome.candidate_id, outcome.error_message or outcome.outcome))
            pub.publish(
                "social.token.refresh_failed",
                candidate_id=outcome.candidate_id,
                payload={
                    "outcome": outcome.outcome,
                    "error_code": outcome.error_code,
                },
            )

            # Check for consecutive failures threshold
            failure_count = store.consecutive_failure_count(outcome.candidate_id)
            if failure_count >= MAX_CONSECUTIVE_FAILURES:
                store.mark_expired(outcome.candidate_id)
                summary["expired"] += 1
                pub.publish(
                    "social.token.expired",
                    candidate_id=outcome.candidate_id,
                    payload={
                        "consecutive_failures": failure_count,
                        "last_error": outcome.error_message,
                    },
                )
                if notifier:
                    notifier.alert_token_expired(
                        outcome.candidate_id,
                        outcome.error_message or "persistent refresh failure",
                    )

        time.sleep(rate_limit_pause)

    # Health snapshot at end of pass
    duration_ms = int((datetime.utcnow() - pass_start).total_seconds() * 1000)
    error_rate = summary["failed"] / max(summary["total"], 1)
    status = "ACTIVE"
    if summary["rate_limited"] > 0:
        status = "DEGRADED"
    elif error_rate > 0.10:
        status = "DEGRADED"
    health.report(HealthSnapshot(
        ecosystem_code="E19_TECH_PROVIDER",
        status=status,
        response_time_ms=duration_ms,
        error_rate=error_rate,
        error_count=summary["failed"],
        queue_depth=summary["total"],
    ))

    logger.info("refresh pass complete: %s",
                {k: v for k, v in summary.items() if k != "errors"})
    return summary


# ---------------------------------------------------------------------------
# Per-candidate refresh
# ---------------------------------------------------------------------------

def _refresh_one(
    candidate: RefreshCandidate,
    store: RefreshStore,
    notifier: Optional[StaffNotifier],
) -> RefreshOutcome:
    """Refresh a single candidate's token. Never raises."""
    try:
        blob, key_id = store.read_encrypted_token(candidate.candidate_id)
    except Exception as exc:
        logger.exception("read_encrypted_token failed for candidate=%s", candidate.candidate_id)
        return RefreshOutcome(
            candidate_id=candidate.candidate_id,
            outcome="unknown_error",
            error_message=f"read failed: {type(exc).__name__}",
        )

    try:
        current_token = decrypt_token(blob, key_id)
    except (DecryptionFailedError, MissingKeyError) as exc:
        logger.error("decrypt failed for candidate=%s: %s", candidate.candidate_id, exc)
        return RefreshOutcome(
            candidate_id=candidate.candidate_id,
            outcome="unknown_error",
            error_code=type(exc).__name__,
            error_message="decrypt failed (key rotated or data corrupted)",
        )

    # Call Meta's refresh endpoint.
    # System User tokens refresh by re-issuing from the system user, not by
    # generic OAuth refresh. We POST to /{system_user_id}/access_tokens again.
    try:
        resp = requests.post(
            f"{META_GRAPH_BASE}/{candidate.system_user_id}/access_tokens",
            data={
                "business_app": FACEBOOK_APP_ID,
                "set_token_expires_in_60_days": "true",
                "access_token": current_token,
            },
            timeout=PER_REQUEST_TIMEOUT,
        )
    except requests.Timeout:
        return RefreshOutcome(
            candidate_id=candidate.candidate_id,
            outcome="network_error",
            error_code="timeout",
            error_message=f"timeout after {PER_REQUEST_TIMEOUT}s",
        )
    except requests.RequestException as exc:
        return RefreshOutcome(
            candidate_id=candidate.candidate_id,
            outcome="network_error",
            error_code=type(exc).__name__,
            error_message=str(exc)[:200],
        )

    # Interpret response
    if resp.status_code == 429:
        return RefreshOutcome(
            candidate_id=candidate.candidate_id,
            outcome="rate_limited",
            error_code="429",
        )

    if resp.status_code != 200:
        body = redact_tokens(resp.text)[:300]
        # Meta error shape: {"error": {"code": N, "type": ..., "message": ...}}
        try:
            err = resp.json().get("error", {})
            err_code = str(err.get("code"))
            err_msg = err.get("message", body)
        except Exception:
            err_code = str(resp.status_code)
            err_msg = body

        # Specific error codes Meta documents:
        #   190 = invalid OAuth token
        #   200 = permission denied
        if err_code == "190":
            return RefreshOutcome(
                candidate_id=candidate.candidate_id,
                outcome="access_revoked",
                error_code=err_code,
                error_message="token invalid — likely revoked by candidate",
            )

        return RefreshOutcome(
            candidate_id=candidate.candidate_id,
            outcome="meta_api_error",
            error_code=err_code,
            error_message=err_msg[:200],
        )

    try:
        data = resp.json()
    except ValueError:
        return RefreshOutcome(
            candidate_id=candidate.candidate_id,
            outcome="meta_api_error",
            error_code="non_json_response",
        )

    new_token = data.get("access_token")
    if not new_token:
        return RefreshOutcome(
            candidate_id=candidate.candidate_id,
            outcome="meta_api_error",
            error_code="missing_access_token",
            error_message="response 200 but no access_token field",
        )

    expires_in = int(data.get("expires_in", LONG_LIVED_TOKEN_DURATION_DAYS * 86400))
    new_expires_at = datetime.utcnow() + timedelta(seconds=expires_in)

    # Encrypt and persist
    try:
        new_blob, new_key_id = encrypt_token(new_token)
        store.write_refreshed_token(
            candidate_id=candidate.candidate_id,
            token_blob=new_blob,
            key_id=new_key_id,
            expires_at=new_expires_at,
        )
    except Exception as exc:
        logger.exception("persist refreshed token failed for candidate=%s", candidate.candidate_id)
        return RefreshOutcome(
            candidate_id=candidate.candidate_id,
            outcome="unknown_error",
            error_code=type(exc).__name__,
            error_message="persist failed",
        )

    return RefreshOutcome(
        candidate_id=candidate.candidate_id,
        outcome="success",
        new_expires_at=new_expires_at,
    )


# ---------------------------------------------------------------------------
# Entrypoint for cron
# ---------------------------------------------------------------------------

def main_cron() -> None:
    """
    Cron entrypoint. Wire concrete RefreshStore + StaffNotifier here.
    Concrete implementations live elsewhere; this function intentionally
    raises NotImplementedError until wired up.
    """
    raise NotImplementedError(
        "Wire concrete RefreshStore (psycopg2-backed) and StaffNotifier "
        "(email/Slack) implementations before running."
    )


if __name__ == "__main__":  # pragma: no cover
    main_cron()
