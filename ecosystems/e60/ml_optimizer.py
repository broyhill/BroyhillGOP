"""
E60.ml_optimizer — LP problem statement + predictive model interfaces.

Section 8 scope: STUB the LP problem and the predictive interfaces. Don't
train models in this PR — just define the shape so producers/consumers can
wire up. Training pipelines + scheduled retraining live in a follow-up PR.
"""

from __future__ import annotations

import logging
from dataclasses import dataclass, field
from datetime import datetime, timedelta
from typing import Any, Callable, Dict, List, Optional

try:
    from shared.brain_pentad_contracts import OptimizerDecision, GradedDonor, Channel
except ImportError:  # pragma: no cover
    import sys, pathlib
    sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent.parent.parent))
    from shared.brain_pentad_contracts import OptimizerDecision, GradedDonor, Channel


logger = logging.getLogger("ecosystem60.ml_optimizer")


# ============================================================================
# LP Problem statement
# ============================================================================

@dataclass(frozen=True)
class LPProblemStatement:
    """
    The optimization problem the LP solver maximizes.

    OBJECTIVE
        max  Σ_{c, s}  spend[c,s] * predicted_revenue_per_cent[c, s]

      where:
        c  ∈ Channel    (email, sms, mms, rcs, voice, direct_mail)
        s  ∈ Segment    (e.g. "A_grade_active", "B_grade_lapsed", ...)

    DECISION VARIABLES
        spend[c, s]     ≥ 0      (cents allocated to channel c × segment s)

    CONSTRAINTS
        1. Daily budget cap:
              Σ_{c, s}  spend[c, s]  ≤  daily_cap_cents

        2. Per-channel fatigue cap:
              Σ_{s}  spend[c, s] / unit_cost[c]  ≤  max_sends_per_day[c]

        3. Per-grade fatigue cap:
              for each grade g:
                  Σ over (c, s where s.grade == g)
                       spend[c, s] / unit_cost[c]
                  ≤  max_sends_per_grade_per_day[g]

        4. TCPA / channel compliance:
              spend[sms, s]  = 0  if s.match_tier ∉ {A_EXACT, B_ALIAS}
              spend[email, s] = 0 if s.match_tier ∉ {A_EXACT, B_ALIAS}
              spend[whatsapp, s] = 0 if s.match_tier ≠ A_EXACT

        5. Non-negativity:
              spend[c, s]  ≥  0

    FEASIBILITY: well-formed if budget > 0 and at least one segment has
    A_EXACT or B_ALIAS members. Trivial feasible point: spend = 0 everywhere
    (objective = 0). The optimizer's job is to find a non-trivial maximum.
    """
    daily_cap_cents: int
    channels: List[Channel]
    segments: List[Dict[str, Any]]               # {'name': str, 'match_tier': MatchTier, 'grade': GradeLetter, 'size': int}
    max_sends_per_day_per_channel: Dict[str, int]
    max_sends_per_grade_per_day: Dict[str, int]  # GradeLetter -> int
    unit_cost_per_channel_cents: Dict[str, int]


def build_lp_problem_statement(
    daily_cap_cents: int = 50_000,
    channels: Optional[List[Channel]] = None,
    segments: Optional[List[Dict[str, Any]]] = None,
) -> LPProblemStatement:
    """Build a default LP problem statement for the BroyhillGOP platform.

    Defaults are placeholder; real values come from E11's budget tables and
    E01's segment definitions in production.
    """
    channels = channels or [Channel.EMAIL, Channel.SMS, Channel.RCS,
                            Channel.VOICE, Channel.DIRECT_MAIL]
    segments = segments or [
        {"name": "A_active", "match_tier": "A_EXACT", "grade": "A", "size": 5_000},
        {"name": "B_active", "match_tier": "A_EXACT", "grade": "B", "size": 12_000},
        {"name": "C_active", "match_tier": "A_EXACT", "grade": "C", "size": 30_000},
    ]
    return LPProblemStatement(
        daily_cap_cents=daily_cap_cents,
        channels=channels,
        segments=segments,
        max_sends_per_day_per_channel={
            "email": 50_000, "sms": 5_000, "rcs": 5_000,
            "voice": 1_000, "direct_mail": 10_000,
        },
        max_sends_per_grade_per_day={
            "A": 3_000, "B": 8_000, "C": 15_000, "D": 5_000, "F": 0,
        },
        unit_cost_per_channel_cents={
            "email": 12, "sms": 60, "rcs": 75,
            "voice": 250, "direct_mail": 80,
        },
    )


# ============================================================================
# Predictive model interfaces (STUBS — do not implement in this PR)
# ============================================================================

@dataclass(frozen=True)
class OptimizerInputs:
    """The inputs every predictive function receives."""
    donor: GradedDonor
    channel: Channel
    when: datetime
    historical_lookback_days: int = 90


def p_donate(inputs: OptimizerInputs) -> float:                    # pragma: no cover
    """Probability that this donor responds to a send on this channel at this time.

    STUB — real implementation will be a calibrated gradient-boosted classifier
    trained on (donor × channel × time-of-day × time-of-week × past-send-history).
    Training data: core.cost_ledger joined to send tables. See follow-up PR.
    """
    raise NotImplementedError("p_donate() awaits trained model — see follow-up PR")


def p_unsubscribe(inputs: OptimizerInputs) -> float:               # pragma: no cover
    """Probability the donor unsubscribes after this send.

    STUB — real implementation will use sequence-aware modeling (RNN/transformer
    over the donor's recent send history).
    """
    raise NotImplementedError("p_unsubscribe() awaits trained model — see follow-up PR")


def expected_gift_amount(inputs: OptimizerInputs) -> int:          # pragma: no cover
    """Expected gift amount in cents conditional on donating.

    STUB — real implementation will be a regression on (lifetime_total ×
    largest_gift × match_tier × channel × time-since-last-gift).
    """
    raise NotImplementedError("expected_gift_amount() awaits trained model — see follow-up PR")


def optimal_send_time(inputs: OptimizerInputs) -> datetime:        # pragma: no cover
    """Best UTC time to send to this donor on this channel.

    STUB — real implementation will be a per-donor GMM over historical
    open/click times (with channel-specific priors).
    """
    raise NotImplementedError("optimal_send_time() awaits trained model — see follow-up PR")


# ============================================================================
# MLOptimizer — the top-level optimizer wrapper
# ============================================================================

class MLOptimizer:
    """
    Wraps the LP problem + predictive models into a single decide() call.

    decide() returns an OptimizerDecision payload. In Section 8 scope,
    decide() runs a deterministic placeholder allocator (proportional to
    segment size with the constraints applied) so the contract surface is
    real and testable. Real LP solving (scipy.optimize.linprog or similar)
    lands in the follow-up PR alongside trained predictive models.
    """

    MODEL_VERSION = "p_donate_v0.0_placeholder"

    def __init__(self, db_url: str = None):
        self.db_url = db_url

    def decide(self, lp: Optional[LPProblemStatement] = None) -> OptimizerDecision:
        lp = lp or build_lp_problem_statement()

        # Placeholder: even split across the first 3 channels × first 3 segments,
        # then enforce the daily cap.
        budget = lp.daily_cap_cents
        num_cells = max(1, min(len(lp.channels), 3) * min(len(lp.segments), 3))
        per_cell = budget // num_cells

        allocations: List[Dict[str, Any]] = []
        for c in lp.channels[:3]:
            for s in lp.segments[:3]:
                # TCPA / channel compliance constraint
                if c in (Channel.EMAIL, Channel.SMS, Channel.RCS, Channel.VOICE):
                    if s["match_tier"] not in ("A_EXACT", "B_ALIAS"):
                        continue
                if c == Channel.WHATSAPP and s["match_tier"] != "A_EXACT":
                    continue
                allocations.append({
                    "channel": c.value,
                    "segment": s["name"],
                    "spend_cents": per_cell,
                    "expected_revenue_cents": per_cell * 3,  # placeholder 3:1 ROI assumption
                })

        total_revenue = sum(a["expected_revenue_cents"] for a in allocations)
        total_spend = sum(a["spend_cents"] for a in allocations)
        constraints_satisfied = total_spend <= budget

        return OptimizerDecision(
            allocations=allocations,
            expected_revenue_cents=total_revenue,
            constraints_satisfied=constraints_satisfied,
            model_version=self.MODEL_VERSION,
        )


__all__ = [
    "MLOptimizer",
    "OptimizerInputs",
    "LPProblemStatement",
    "build_lp_problem_statement",
    "p_donate", "p_unsubscribe", "expected_gift_amount", "optimal_send_time",
]
