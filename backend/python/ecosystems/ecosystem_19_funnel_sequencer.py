#!/usr/bin/env python3
"""
ECOSYSTEM 19 — Funnel Sequencer

Donor lifecycle staging + content-stage gate. Authoritative reference:
docs/architecture/E19_FUNNEL_STAGES.md

Stages (one-way, forward only):
  STRANGER -> AWARE -> ENGAGED -> SUBSCRIBER -> SMALL_DONOR -> REPEAT_DONOR -> BUNDLER

The hard gate: a donor at stage X may receive content tagged for stage X or any
LOWER stage. Anything else is BLOCKED at check_funnel_stage_gate().

Read-only against core.donor_profile and consent tables. UPSERTs into
core.e19_donor_funnel via evaluate_stage_transition().
"""
from __future__ import annotations

import logging
import os
from dataclasses import dataclass
from datetime import datetime
from enum import Enum
from typing import Iterable, Optional, Set

import psycopg2
from psycopg2.extras import RealDictCursor

logger = logging.getLogger("ecosystem19.funnel_sequencer")


# ============================================================================
# Funnel + Content stage enums
# ============================================================================

class FunnelStage(str, Enum):
    STRANGER     = "STRANGER"
    AWARE        = "AWARE"
    ENGAGED      = "ENGAGED"
    SUBSCRIBER   = "SUBSCRIBER"
    SMALL_DONOR  = "SMALL_DONOR"
    REPEAT_DONOR = "REPEAT_DONOR"
    BUNDLER      = "BUNDLER"


# Ordered ladder for "may receive same-or-lower" rule.
_STAGE_LADDER = [
    FunnelStage.STRANGER,
    FunnelStage.AWARE,
    FunnelStage.ENGAGED,
    FunnelStage.SUBSCRIBER,
    FunnelStage.SMALL_DONOR,
    FunnelStage.REPEAT_DONOR,
    FunnelStage.BUNDLER,
]


class ContentStage(str, Enum):
    # Stage-1 (STRANGER-appropriate) tags
    ISSUE_EDUCATION         = "issue_education"
    NO_ASK                  = "no_ask"
    NO_CANDIDATE_FACE       = "no_candidate_face"
    # Stage-2 (AWARE) tags
    CANDIDATE_HUMANIZATION  = "candidate_humanization"
    STORY                   = "story"
    FAMILY                  = "family"
    VALUES                  = "values"
    # Stage-3 (ENGAGED)
    ISSUE_ALIGNMENT         = "issue_alignment"
    POSITION_CLARIFICATION  = "position_clarification"
    POLICY_DEEP_DIVE        = "policy_deep_dive"
    # Stage-4 (SUBSCRIBER)
    BEHIND_THE_SCENES       = "behind_the_scenes"
    INTIMACY                = "intimacy"
    LOW_FRICTION_ASK        = "low_friction_ask"
    # Stage-5 (SMALL_DONOR)
    IMPACT_REPORT           = "impact_report"
    FUNDED_THIS             = "funded_this"
    MEDIUM_ASK              = "medium_ask"
    # Stage-6 (REPEAT_DONOR)
    PEER_VALIDATION         = "peer_validation"
    LARGER_ASK              = "larger_ask"
    COMMUNITY_SIGNAL        = "community_signal"
    # Stage-7 (BUNDLER)
    VIP_ACCESS              = "vip_access"
    EXCLUSIVE_BRIEFING      = "exclusive_briefing"
    HOST_INVITE             = "host_invite"
    INNER_CIRCLE            = "inner_circle"


# Per-stage allowed content set (cumulative — each stage gets its own + all lower).
# See docs/architecture/E19_FUNNEL_STAGES.md §3 for the rule mapping.
_PER_STAGE_NEW_TAGS: dict[FunnelStage, Set[ContentStage]] = {
    FunnelStage.STRANGER: {
        ContentStage.ISSUE_EDUCATION,
        ContentStage.NO_ASK,
        ContentStage.NO_CANDIDATE_FACE,
    },
    FunnelStage.AWARE: {
        ContentStage.CANDIDATE_HUMANIZATION,
        ContentStage.STORY,
        ContentStage.FAMILY,
        ContentStage.VALUES,
    },
    FunnelStage.ENGAGED: {
        ContentStage.ISSUE_ALIGNMENT,
        ContentStage.POSITION_CLARIFICATION,
        ContentStage.POLICY_DEEP_DIVE,
    },
    FunnelStage.SUBSCRIBER: {
        ContentStage.BEHIND_THE_SCENES,
        ContentStage.INTIMACY,
        ContentStage.LOW_FRICTION_ASK,
    },
    FunnelStage.SMALL_DONOR: {
        ContentStage.IMPACT_REPORT,
        ContentStage.FUNDED_THIS,
        ContentStage.MEDIUM_ASK,
    },
    FunnelStage.REPEAT_DONOR: {
        ContentStage.PEER_VALIDATION,
        ContentStage.LARGER_ASK,
        ContentStage.COMMUNITY_SIGNAL,
    },
    FunnelStage.BUNDLER: {
        ContentStage.VIP_ACCESS,
        ContentStage.EXCLUSIVE_BRIEFING,
        ContentStage.HOST_INVITE,
        ContentStage.INNER_CIRCLE,
    },
}


# ============================================================================
# Per-stage fatigue caps (inlined from the spec — moves to shared/fatigue_caps.py
# when that module lands; tracked in ADR 2026-05-03 Known Gaps).
# Format: stage -> (max_sends_per_period, period_days)
# ============================================================================

FATIGUE_CAPS: dict[FunnelStage, tuple[int, int]] = {
    FunnelStage.STRANGER:     (3,  7),   # 3 ad impressions per week
    FunnelStage.AWARE:        (5,  7),
    FunnelStage.ENGAGED:      (8,  7),
    FunnelStage.SUBSCRIBER:   (3,  7),   # owned channel — careful with frequency
    FunnelStage.SMALL_DONOR:  (4,  7),
    FunnelStage.REPEAT_DONOR: (5,  7),
    FunnelStage.BUNDLER:      (2, 14),   # bundlers get fewer, higher-quality touches
}


# ============================================================================
# Public API
# ============================================================================

def allowed_content_stages(donor_stage: FunnelStage) -> Set[ContentStage]:
    """Return the SET of ContentStage values a donor at `donor_stage` MAY receive.

    A donor may receive content tagged for their stage OR any LOWER stage on
    the ladder. Bundlers may receive everything; strangers ONLY stranger-tier.
    """
    if donor_stage not in _STAGE_LADDER:
        return set()
    cutoff = _STAGE_LADDER.index(donor_stage)
    allowed: Set[ContentStage] = set()
    for stage in _STAGE_LADDER[: cutoff + 1]:
        allowed |= _PER_STAGE_NEW_TAGS.get(stage, set())
    return allowed


def is_content_allowed(donor_stage: FunnelStage,
                        content_stage: ContentStage) -> bool:
    """Convenience wrapper for the gate. Returns True if allowed, False if blocked."""
    return content_stage in allowed_content_stages(donor_stage)


def fatigue_window_for(donor_stage: FunnelStage) -> tuple[int, int]:
    """Returns (max_sends, period_days) for the donor's stage."""
    return FATIGUE_CAPS.get(donor_stage, (1, 7))


# ============================================================================
# Stage evaluation against core.donor_profile + consent tables
# ============================================================================

@dataclass
class _DonorSignals:
    """Slim view of signals used to decide funnel stage."""
    has_donor_profile: bool
    txn_count: int
    lifetime_total_cents: int
    is_bundler_flag: bool
    has_email_consent: bool
    has_sms_consent: bool
    has_engagement_signal: bool


def _read_signals(rnc_regid: str, db_url: str) -> Optional[_DonorSignals]:
    """Read the signals required to compute a stage. Returns None if no record."""
    conn = psycopg2.connect(db_url)
    try:
        with conn.cursor(cursor_factory=RealDictCursor) as cur:
            # core.donor_profile lookup
            cur.execute(
                "SELECT txn_count, lifetime_total, "
                "       COALESCE(is_bundler, FALSE) AS is_bundler "
                "FROM core.donor_profile "
                "WHERE rnc_regid = %s LIMIT 1",
                (rnc_regid,),
            )
            row = cur.fetchone()
            if not row:
                # No donor record — could still be a SUBSCRIBER if they have consent.
                has_email = _has_consent_row(cur, rnc_regid, "core.email_consent")
                has_sms = _has_messaging_sms_consent(cur, rnc_regid)
                if not (has_email or has_sms):
                    return None  # Truly stranger / unknown.
                return _DonorSignals(
                    has_donor_profile=False, txn_count=0, lifetime_total_cents=0,
                    is_bundler_flag=False,
                    has_email_consent=has_email, has_sms_consent=has_sms,
                    has_engagement_signal=False,
                )
            txn_count = int(row["txn_count"] or 0)
            lifetime_total_cents = int((row["lifetime_total"] or 0) * 100)
            is_bundler = bool(row.get("is_bundler"))
            has_email = _has_consent_row(cur, rnc_regid, "core.email_consent")
            has_sms = _has_messaging_sms_consent(cur, rnc_regid)
            return _DonorSignals(
                has_donor_profile=True, txn_count=txn_count,
                lifetime_total_cents=lifetime_total_cents,
                is_bundler_flag=is_bundler,
                has_email_consent=has_email, has_sms_consent=has_sms,
                has_engagement_signal=(txn_count > 0),
            )
    finally:
        conn.close()


def _has_consent_row(cur, rnc_regid: str, table: str) -> bool:
    """Check email_consent (or analogous table) for a non-revoked row."""
    try:
        cur.execute(
            f"SELECT 1 FROM {table} "
            "WHERE rnc_regid = %s AND revoked_at IS NULL LIMIT 1",
            (rnc_regid,),
        )
        return cur.fetchone() is not None
    except Exception:
        # Table may not exist yet in all environments; treat as no consent.
        return False


def _has_messaging_sms_consent(cur, rnc_regid: str) -> bool:
    """Check messaging_consent.sms_status='opted_in' joined via phone in donor_profile."""
    try:
        cur.execute(
            "SELECT 1 FROM messaging_consent mc "
            "JOIN core.donor_profile dp ON dp.cell_phone = mc.phone_number "
            "WHERE dp.rnc_regid = %s AND mc.sms_status = 'opted_in' LIMIT 1",
            (rnc_regid,),
        )
        return cur.fetchone() is not None
    except Exception:
        return False


def _signals_to_stage(s: _DonorSignals) -> FunnelStage:
    """Pure function: signals -> funnel stage.

    Order matters: check from highest stage down so a bundler-eligible donor
    doesn't get demoted to SMALL_DONOR by an earlier rule match.
    """
    # BUNDLER: explicit flag OR ≥$2,500 lifetime.
    if s.is_bundler_flag or s.lifetime_total_cents >= 250_000:
        return FunnelStage.BUNDLER
    # REPEAT_DONOR: ≥3 txns OR ≥$500 lifetime.
    if s.txn_count >= 3 or s.lifetime_total_cents >= 50_000:
        return FunnelStage.REPEAT_DONOR
    # SMALL_DONOR: any donation history.
    if s.txn_count >= 1 or s.lifetime_total_cents > 0:
        return FunnelStage.SMALL_DONOR
    # SUBSCRIBER: opted in to email or SMS.
    if s.has_email_consent or s.has_sms_consent:
        return FunnelStage.SUBSCRIBER
    # ENGAGED: has any engagement signal (click, video completion, inbound msg).
    if s.has_engagement_signal:
        return FunnelStage.ENGAGED
    # AWARE: donor profile exists but no engagement.
    if s.has_donor_profile:
        return FunnelStage.AWARE
    # STRANGER: no record at all (or only ad impressions).
    return FunnelStage.STRANGER


def get_donor_stage(rnc_regid: str,
                    db_url: Optional[str] = None,
                    signals: Optional[_DonorSignals] = None) -> FunnelStage:
    """Public function. Reads signals (or accepts pre-fetched) and returns stage.

    `signals` is the test injection point — pass a _DonorSignals to bypass DB.
    """
    if signals is None:
        db_url = db_url or os.getenv("DATABASE_URL", "postgresql://localhost/broyhillgop")
        signals = _read_signals(rnc_regid, db_url)
        if signals is None:
            return FunnelStage.STRANGER
    return _signals_to_stage(signals)


def evaluate_stage_transition(rnc_regid: str, candidate_id: str,
                               db_url: Optional[str] = None) -> FunnelStage:
    """Recompute stage and UPSERT to core.e19_donor_funnel. Returns the new stage.

    Forward-only: if the new computed stage is LOWER than the persisted one,
    we keep the persisted one (donors don't move backward).
    """
    db_url = db_url or os.getenv("DATABASE_URL", "postgresql://localhost/broyhillgop")
    new_stage = get_donor_stage(rnc_regid, db_url=db_url)
    conn = psycopg2.connect(db_url)
    try:
        with conn.cursor() as cur:
            cur.execute(
                "SELECT funnel_stage FROM core.e19_donor_funnel "
                "WHERE rnc_regid = %s AND candidate_id = %s",
                (rnc_regid, candidate_id),
            )
            row = cur.fetchone()
            persisted = FunnelStage(row[0]) if row else None
            if persisted is not None:
                # Forward-only enforcement.
                if _STAGE_LADDER.index(new_stage) < _STAGE_LADDER.index(persisted):
                    new_stage = persisted
            cur.execute(
                "INSERT INTO core.e19_donor_funnel "
                "    (rnc_regid, candidate_id, funnel_stage, "
                "     stage_entered_at, last_evaluated_at) "
                "VALUES (%s, %s, %s, NOW(), NOW()) "
                "ON CONFLICT (rnc_regid, candidate_id) DO UPDATE SET "
                "    funnel_stage = EXCLUDED.funnel_stage, "
                "    stage_entered_at = "
                "        CASE WHEN core.e19_donor_funnel.funnel_stage "
                "                  = EXCLUDED.funnel_stage "
                "             THEN core.e19_donor_funnel.stage_entered_at "
                "             ELSE NOW() END, "
                "    last_evaluated_at = NOW()",
                (rnc_regid, candidate_id, new_stage.value),
            )
        conn.commit()
    finally:
        conn.close()
    logger.info(f"funnel_sequencer.evaluate {rnc_regid} -> {new_stage.value}")
    return new_stage


__all__ = [
    "FunnelStage", "ContentStage",
    "FATIGUE_CAPS",
    "allowed_content_stages", "is_content_allowed", "fatigue_window_for",
    "get_donor_stage", "evaluate_stage_transition",
]
