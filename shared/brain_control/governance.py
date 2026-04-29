"""
shared/brain_control/governance.py

Three governance helpers for ecosystems integrating with the Brain:

1. HealthReporter — periodic INSERT into brain_control.ecosystem_health
2. CostAccountant — tracks per-function call costs in brain_control accounting
3. SelfCorrectionReader — reads automation pause/throttle directives the Brain emits

All three are abstract interfaces — concrete impls (psycopg2-backed) live in
infrastructure/. This module defines the contracts and a no-op fallback for
tests.

Phase: Step 5b. Dry-run only.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timezone
from enum import Enum
from typing import Optional, Protocol


logger = logging.getLogger("shared.brain_control.governance")


# ---------------------------------------------------------------------------
# Health reporting
# ---------------------------------------------------------------------------

@dataclass
class HealthSnapshot:
    """One row of brain_control.ecosystem_health."""
    ecosystem_code: str
    status: str                                  # 'ACTIVE', 'DEGRADED', 'OFFLINE', etc.
    response_time_ms: Optional[int] = None
    throughput_rps: Optional[float] = None
    cpu_usage: Optional[float] = None
    memory_usage: Optional[float] = None
    active_connections: int = 0
    queue_depth: int = 0
    queue_latency_ms: Optional[int] = None
    error_rate: float = 0.0
    error_count: int = 0
    last_error: Optional[str] = None
    degraded_functions: list[str] = field(default_factory=list)


class HealthReporter(Protocol):
    """
    Records health snapshots into brain_control.ecosystem_health.
    Concrete impl uses psycopg2; no-op impl below for tests.
    """

    def report(self, snapshot: HealthSnapshot) -> None: ...


class NullHealthReporter:
    """No-op for tests / when brain_control isn't reachable."""

    def report(self, snapshot: HealthSnapshot) -> None:
        logger.debug("NullHealthReporter: dropping snapshot for %s", snapshot.ecosystem_code)


# ---------------------------------------------------------------------------
# Cost accounting
# ---------------------------------------------------------------------------

@dataclass
class FunctionCallRecord:
    """One function-call accounting entry."""
    function_code: str                            # e.g. 'F901'
    candidate_id: Optional[str] = None
    call_count: int = 1
    actual_cost: float = 0.0                      # USD; usually 0 for Meta API
    duration_ms: Optional[int] = None
    success: bool = True
    error_type: Optional[str] = None
    metadata: Optional[dict] = None


class CostAccountant(Protocol):
    """
    Records function calls for cost accounting.
    Aggregated daily into brain_control variance/forecast tables.
    """

    def record_call(self, record: FunctionCallRecord) -> None: ...


class NullCostAccountant:
    """No-op for tests."""

    def record_call(self, record: FunctionCallRecord) -> None:
        logger.debug("NullCostAccountant: dropping record for %s", record.function_code)


# ---------------------------------------------------------------------------
# Self-correction / Brain directives
# ---------------------------------------------------------------------------

class AutomationDirective(Enum):
    """States the Brain can put a candidate or the entire app into."""
    FULL = "full"            # Normal operation
    REDUCED = "reduced"      # Throttle: half rate, lower priority
    PAUSED = "paused"        # Halt all automation
    EXPANDED = "expanded"    # Increase rate (Brain has high confidence in actions)


@dataclass(frozen=True)
class CandidateDirective:
    candidate_id: str
    directive: AutomationDirective
    reason: Optional[str] = None
    set_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None


@dataclass(frozen=True)
class AppWideDirective:
    directive: AutomationDirective
    reason: Optional[str] = None
    set_at: Optional[datetime] = None
    expires_at: Optional[datetime] = None


class SelfCorrectionReader(Protocol):
    """
    Reads current automation directives from brain_control.

    Tech Provider services (OAuth handler, refresh worker, etc.) check
    these before performing automation actions. If app-wide is PAUSED,
    skip everything. If a candidate is PAUSED, skip just that candidate.
    """

    def get_app_wide(self) -> AppWideDirective: ...
    def get_for_candidate(self, candidate_id: str) -> CandidateDirective: ...


class NullSelfCorrectionReader:
    """No-op: always returns FULL. Use for tests or when brain_control offline."""

    def get_app_wide(self) -> AppWideDirective:
        return AppWideDirective(
            directive=AutomationDirective.FULL,
            set_at=datetime.now(timezone.utc),
        )

    def get_for_candidate(self, candidate_id: str) -> CandidateDirective:
        return CandidateDirective(
            candidate_id=candidate_id,
            directive=AutomationDirective.FULL,
            set_at=datetime.now(timezone.utc),
        )


# ---------------------------------------------------------------------------
# Helpers used by service code
# ---------------------------------------------------------------------------

def is_paused(reader: SelfCorrectionReader, candidate_id: Optional[str] = None) -> bool:
    """
    Convenience: return True if app-wide OR per-candidate directive is PAUSED.
    Service code calls this before performing actions:

        if is_paused(corrector, candidate_id):
            logger.info("automation paused; skipping")
            return
    """
    app_directive = reader.get_app_wide()
    if app_directive.directive == AutomationDirective.PAUSED:
        return True
    if candidate_id:
        cand_directive = reader.get_for_candidate(candidate_id)
        if cand_directive.directive == AutomationDirective.PAUSED:
            return True
    return False


__all__ = [
    "HealthReporter",
    "NullHealthReporter",
    "HealthSnapshot",
    "CostAccountant",
    "NullCostAccountant",
    "FunctionCallRecord",
    "SelfCorrectionReader",
    "NullSelfCorrectionReader",
    "AutomationDirective",
    "CandidateDirective",
    "AppWideDirective",
    "is_paused",
]
