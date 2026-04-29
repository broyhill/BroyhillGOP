"""
ecosystems/E19_social/onboarding/tests/test_brain_governance.py

Tests for shared/brain_control/governance.py and integration of services
with self-correction directives.
"""

from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock
from uuid import uuid4

import pytest

from shared.brain_control import (
    HealthReporter,
    CostAccountant,
    SelfCorrectionReader,
    AutomationDirective,
)
from shared.brain_control.governance import (
    HealthSnapshot,
    FunctionCallRecord,
    NullHealthReporter,
    NullCostAccountant,
    NullSelfCorrectionReader,
    CandidateDirective,
    AppWideDirective,
    is_paused,
)


# ---------------------------------------------------------------------------
# HealthSnapshot
# ---------------------------------------------------------------------------

class TestHealthSnapshot:
    def test_construct_with_required_fields_only(self):
        snap = HealthSnapshot(ecosystem_code="E19_TECH_PROVIDER", status="ACTIVE")
        assert snap.ecosystem_code == "E19_TECH_PROVIDER"
        assert snap.status == "ACTIVE"
        assert snap.error_count == 0
        assert snap.degraded_functions == []

    def test_construct_with_metrics(self):
        snap = HealthSnapshot(
            ecosystem_code="E19_TECH_PROVIDER",
            status="DEGRADED",
            response_time_ms=4500,
            error_rate=0.15,
            queue_depth=12,
        )
        assert snap.status == "DEGRADED"
        assert snap.response_time_ms == 4500
        assert snap.error_rate == 0.15


class TestNullHealthReporter:
    def test_drops_snapshots_silently(self):
        reporter = NullHealthReporter()
        # Should not raise
        reporter.report(HealthSnapshot(ecosystem_code="E19_TECH_PROVIDER", status="ACTIVE"))


# ---------------------------------------------------------------------------
# FunctionCallRecord
# ---------------------------------------------------------------------------

class TestFunctionCallRecord:
    def test_construct_minimal(self):
        rec = FunctionCallRecord(function_code="F901")
        assert rec.function_code == "F901"
        assert rec.success is True
        assert rec.call_count == 1
        assert rec.actual_cost == 0.0

    def test_construct_with_failure(self):
        rec = FunctionCallRecord(
            function_code="F902",
            candidate_id=str(uuid4()),
            success=False,
            error_type="rate_limited",
            duration_ms=2500,
        )
        assert rec.success is False
        assert rec.error_type == "rate_limited"


class TestNullCostAccountant:
    def test_drops_records_silently(self):
        a = NullCostAccountant()
        a.record_call(FunctionCallRecord(function_code="F901"))


# ---------------------------------------------------------------------------
# Self-correction reader
# ---------------------------------------------------------------------------

class TestNullSelfCorrectionReader:
    def test_default_app_wide_is_full(self):
        r = NullSelfCorrectionReader()
        d = r.get_app_wide()
        assert d.directive == AutomationDirective.FULL
        assert d.set_at is not None

    def test_default_candidate_is_full(self):
        r = NullSelfCorrectionReader()
        cid = str(uuid4())
        d = r.get_for_candidate(cid)
        assert d.directive == AutomationDirective.FULL
        assert d.candidate_id == cid


class TestIsPaused:
    def _reader_with(self, app_directive, cand_directive=None):
        reader = MagicMock()
        reader.get_app_wide.return_value = AppWideDirective(directive=app_directive)
        if cand_directive is not None:
            reader.get_for_candidate.return_value = CandidateDirective(
                candidate_id="x",
                directive=cand_directive,
            )
        else:
            reader.get_for_candidate.return_value = CandidateDirective(
                candidate_id="x",
                directive=AutomationDirective.FULL,
            )
        return reader

    def test_full_returns_false(self):
        r = self._reader_with(AutomationDirective.FULL)
        assert is_paused(r) is False

    def test_app_wide_paused_returns_true(self):
        r = self._reader_with(AutomationDirective.PAUSED)
        assert is_paused(r) is True

    def test_app_wide_paused_returns_true_even_with_candidate(self):
        r = self._reader_with(AutomationDirective.PAUSED, AutomationDirective.FULL)
        assert is_paused(r, candidate_id="abc") is True

    def test_candidate_paused_with_app_full_returns_true(self):
        r = self._reader_with(AutomationDirective.FULL, AutomationDirective.PAUSED)
        assert is_paused(r, candidate_id="abc") is True

    def test_reduced_not_treated_as_paused(self):
        r = self._reader_with(AutomationDirective.REDUCED)
        # REDUCED means throttle, not stop. Different from PAUSED.
        assert is_paused(r) is False

    def test_no_candidate_id_only_checks_app_wide(self):
        r = self._reader_with(AutomationDirective.FULL, AutomationDirective.PAUSED)
        # No candidate passed → only app-wide check
        assert is_paused(r) is False


# ---------------------------------------------------------------------------
# Service integration: refresh worker honors pause
# ---------------------------------------------------------------------------

class TestRefreshWorkerHonorsPause:
    def test_app_wide_pause_skips_entire_pass(self, monkeypatch):
        """When app-wide is PAUSED, refresh worker should skip the pass entirely."""
        import base64, os
        from shared.security.token_vault import reload_keys

        monkeypatch.setenv(
            "META_TOKEN_KEY_v1",
            base64.b64encode(os.urandom(32)).decode("ascii"),
        )
        monkeypatch.setenv("META_TOKEN_ACTIVE_KEY_ID", "v1")
        reload_keys()

        from ecosystems.E19_social.onboarding.token_refresh_worker import run_refresh_pass

        store = MagicMock()
        # If we got past the pause check, this would return candidates
        store.list_candidates_needing_refresh.return_value = ["should-not-be-touched"]

        paused_reader = MagicMock()
        paused_reader.get_app_wide.return_value = AppWideDirective(
            directive=AutomationDirective.PAUSED,
            reason="brain_decided_pause",
        )

        summary = run_refresh_pass(
            store=store,
            self_correction=paused_reader,
            rate_limit_pause=0,
        )

        assert summary["paused"] is True
        assert summary["total"] == 0
        # store.list_candidates_needing_refresh should NOT have been called
        store.list_candidates_needing_refresh.assert_not_called()
