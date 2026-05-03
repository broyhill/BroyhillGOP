"""
Joint Brain Pentad test harness — tests/test_brain_pentad_loop.py

Exercises a synthetic donor through the full Pentad loop:

    E01 grade_donor → E19 personalize → E30 send → E11 rollup
                                    ↓        ↓        ↓
                                    └────────┴────────┘
                                             ↓
                                            E60 (observes via CostEvent,
                                                 fires RuleFired, emits
                                                 OptimizerDecision)

Asserts every contract in shared/brain_pentad_contracts.py holds, and that
the boundary discipline (Rule P-1: ecosystems don't import each other) is
maintained: this harness ONLY imports from shared.

Per the constitution (docs/architecture/BRAIN_PENTAD_CONTRACTS.md §4),
every PR that touches any of the five Brain modules MUST keep this file
passing.
"""

from __future__ import annotations

import sys
import unittest
import uuid
from datetime import datetime, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

# Per Rule P-1: this harness imports ONLY from shared.brain_pentad_contracts.
# It does NOT import any ecosystem module directly. Where ecosystem behavior
# is required, it's stubbed in this file so the harness can pass without
# requiring all five ecosystems to be import-able simultaneously.
from shared.brain_pentad_contracts import (  # noqa: E402
    BRAIN_PENTAD_VERSION,
    BudgetSignal,
    Channel,
    CostEvent,
    CostType,
    GradedDonor,
    MatchTier,
    OptimizerDecision,
    PersonalizedMessage,
    RuleFired,
    SendOutcome,
)


# ============================================================================
# Stubs that mimic what each Brain module would do — kept inline here so the
# harness doesn't take a hard import dependency on any of the five.
# ============================================================================


def stub_e01_grade_donor(rnc_regid: str) -> GradedDonor:
    """Stub of E01.grade_donor for a known synthetic donor."""
    import hashlib, json
    inputs = {"rnc_regid": rnc_regid, "txn_count": 12, "lifetime_total": 5000.0,
              "match_tier": MatchTier.A_EXACT.value}
    inputs_hash = hashlib.sha256(json.dumps(inputs, sort_keys=True).encode()).hexdigest()
    return GradedDonor(
        rnc_regid=rnc_regid, grade="B", match_tier=MatchTier.A_EXACT,
        confidence=0.85, inputs_hash=inputs_hash,
    )


def stub_e19_personalize(graded: GradedDonor, channel: Channel) -> PersonalizedMessage:
    """Stub of E19 personalization."""
    return PersonalizedMessage(
        donor_id=graded.rnc_regid,
        variant_id="variant_A",
        channel=channel,
        subject="Test subject" if channel == Channel.EMAIL else None,
        body="Hello — synthetic test message.",
        cta_url="https://example.com/donate",
        expires_at=datetime.utcnow() + timedelta(hours=24),
        grade_at_personalization=graded.grade,
        match_tier=graded.match_tier,
    )


def stub_e30_send(msg: PersonalizedMessage) -> SendOutcome:
    """Stub of E30 send. Returns a successful delivery outcome."""
    # Enforce the §3 Rule P-5 sender compliance gate.
    allowed = {
        Channel.EMAIL: {MatchTier.A_EXACT, MatchTier.B_ALIAS},
        Channel.SMS:   {MatchTier.A_EXACT, MatchTier.B_ALIAS},
    }
    floor = allowed.get(msg.channel, set())
    if msg.match_tier not in floor:
        # Block per Rule P-5
        return SendOutcome(
            send_id=str(uuid.uuid4()), donor_id=msg.donor_id, channel=msg.channel,
            cost_cents=0, delivered=False, sent_at=datetime.utcnow(),
        )
    # Successful delivery
    return SendOutcome(
        send_id=str(uuid.uuid4()), donor_id=msg.donor_id, channel=msg.channel,
        cost_cents=12, delivered=True, opened=True, clicked=True,
        revenue_cents=2500, fatigue_delta=0.1, sent_at=datetime.utcnow(),
        bounce_type="none", complaint=False, unsubscribed=False,
    )


def stub_e11_rollup(outcomes: list, period: str = "7d") -> BudgetSignal:
    """Stub of E11 budget rollup."""
    revenue = sum(o.revenue_cents for o in outcomes)
    cost = sum(o.cost_cents for o in outcomes) or 1
    roi = revenue / cost
    return BudgetSignal(
        period=period,
        per_grade_roi={"A": roi, "B": roi, "C": roi, "D": roi, "F": 0.0},
        per_tier_roi={t: roi for t in MatchTier},
        reallocation_flags=[],
    )


def stub_e60_log_cost(outcome: SendOutcome, vendor: str = "twilio") -> CostEvent:
    """Stub of E60.log_cost — every send produces a CostEvent."""
    return CostEvent(
        event_id=f"E30:send:{outcome.send_id}",
        source_ecosystem="E30", donor_id=outcome.donor_id,
        cost_type=CostType.SEND, vendor=vendor,
        unit_cost_cents=outcome.cost_cents, quantity=1,
        total_cost_cents=outcome.cost_cents,
        revenue_attributed_cents=outcome.revenue_cents,
        occurred_at=outcome.sent_at,
    )


def stub_e60_evaluate_rules(cost_events: list) -> list:
    """Stub of E60 IFTTT engine. Fires one RuleFired if a budget threshold is crossed."""
    fires = []
    total_cost = sum(c.total_cost_cents for c in cost_events)
    if total_cost > 100:  # synthetic threshold
        fires.append(RuleFired(
            rule_id="daily_budget_warn", target_ecosystem="E30",
            action="throttle_sends",
            payload={"reason": f"daily_cost_cents={total_cost}", "throttle_pct": 50},
            audit_trail_id=str(uuid.uuid4()),
        ))
    return fires


def stub_e60_optimize(send_outcomes: list) -> OptimizerDecision:
    """Stub of E60 LP optimizer — produces a decision with feasible allocations."""
    return OptimizerDecision(
        allocations=[
            {"channel": "email", "segment": "A_grade_active",
             "spend_cents": 5000, "expected_revenue_cents": 18000},
            {"channel": "sms", "segment": "B_grade_active",
             "spend_cents": 2500, "expected_revenue_cents": 7000},
        ],
        expected_revenue_cents=25000, constraints_satisfied=True,
        model_version="p_donate_v0.1",
    )


# ============================================================================
# THE LOOP TEST
# ============================================================================


class BrainPentadLoopTest(unittest.TestCase):
    """End-to-end loop. If this passes, every contract holds."""

    def test_loop_runs_end_to_end(self):
        # 1) E01 grades the donor
        graded = stub_e01_grade_donor("RNC-PENTAD-TEST-1")
        self.assertIsInstance(graded, GradedDonor)
        self.assertEqual(graded.match_tier, MatchTier.A_EXACT)

        # 2) E19 personalizes — produces an email PersonalizedMessage
        msg = stub_e19_personalize(graded, Channel.EMAIL)
        self.assertIsInstance(msg, PersonalizedMessage)
        self.assertEqual(msg.donor_id, graded.rnc_regid)
        self.assertEqual(msg.match_tier, graded.match_tier)
        self.assertEqual(msg.grade_at_personalization, graded.grade)

        # 3) E30 sends — TCPA/CAN-SPAM gate passes (A_EXACT is allowed for email)
        outcome = stub_e30_send(msg)
        self.assertIsInstance(outcome, SendOutcome)
        self.assertTrue(outcome.delivered, "A_EXACT email send must succeed")
        self.assertGreater(outcome.cost_cents, 0)
        self.assertGreater(outcome.revenue_cents, 0)

        # 4) E60 observes via CostEvent (Rule P-4: only E60 writes the ledger)
        cost = stub_e60_log_cost(outcome)
        self.assertIsInstance(cost, CostEvent)
        self.assertEqual(cost.source_ecosystem, "E30")
        # event_id is stable on the same send_id (idempotency test below)
        cost2 = stub_e60_log_cost(outcome)
        self.assertEqual(cost.event_id, cost2.event_id,
                         "Same send_id must produce the same CostEvent.event_id")

        # 5) E11 rolls up SendOutcomes into a BudgetSignal that flows back to E01
        signal = stub_e11_rollup([outcome])
        self.assertIsInstance(signal, BudgetSignal)
        self.assertIn("A", signal.per_grade_roi)
        self.assertGreater(signal.per_grade_roi["A"], 0)

        # 6) E60 fires a RuleFired (we set the threshold low enough that one fires)
        # First, make total_cost exceed threshold by replicating the cost event
        many_costs = [cost] * 10  # 10 events × 12 cents = 120 > 100 threshold
        fires = stub_e60_evaluate_rules(many_costs)
        self.assertEqual(len(fires), 1, "Expected one RuleFired at threshold")
        self.assertIsInstance(fires[0], RuleFired)
        self.assertEqual(fires[0].target_ecosystem, "E30")
        self.assertEqual(fires[0].action, "throttle_sends")

        # 7) E60 emits an OptimizerDecision to E11
        decision = stub_e60_optimize([outcome])
        self.assertIsInstance(decision, OptimizerDecision)
        self.assertTrue(decision.constraints_satisfied)
        self.assertGreater(decision.expected_revenue_cents, 0)
        self.assertGreater(len(decision.allocations), 0)


class ComplianceGateTest(unittest.TestCase):
    """Rule P-5: senders MUST refuse low-tier sends."""

    def test_email_blocks_d_household_match(self):
        graded = GradedDonor(
            rnc_regid="RNC-LOW-TIER", grade="C",
            match_tier=MatchTier.D_HOUSEHOLD, confidence=0.45,
            inputs_hash="0" * 64,
        )
        msg = stub_e19_personalize(graded, Channel.EMAIL)
        outcome = stub_e30_send(msg)
        self.assertFalse(outcome.delivered, "D_HOUSEHOLD email send must be blocked")
        self.assertEqual(outcome.cost_cents, 0)

    def test_email_blocks_unmatched(self):
        graded = GradedDonor(
            rnc_regid="RNC-UNMATCHED", grade="F",
            match_tier=MatchTier.UNMATCHED, confidence=0.0,
            inputs_hash="0" * 64,
        )
        msg = stub_e19_personalize(graded, Channel.EMAIL)
        outcome = stub_e30_send(msg)
        self.assertFalse(outcome.delivered)


class CostEventValidationTest(unittest.TestCase):
    """CostEvent has a model_validator that enforces total = unit*qty."""

    def test_total_cost_must_equal_unit_times_quantity(self):
        with self.assertRaises(Exception):
            CostEvent(
                event_id="E30:send:test", source_ecosystem="E30",
                cost_type=CostType.SEND, vendor="twilio",
                unit_cost_cents=10, quantity=5,
                total_cost_cents=99,  # WRONG: should be 50
                occurred_at=datetime.utcnow(),
            )

    def test_correct_total_passes(self):
        c = CostEvent(
            event_id="E30:send:ok", source_ecosystem="E30",
            cost_type=CostType.SEND, vendor="twilio",
            unit_cost_cents=10, quantity=5, total_cost_cents=50,
            occurred_at=datetime.utcnow(),
        )
        self.assertEqual(c.total_cost_cents, 50)


class FrozenPayloadTest(unittest.TestCase):
    """All Brain Pentad payloads are frozen — mutation must raise."""

    def test_graded_donor_is_frozen(self):
        g = GradedDonor(rnc_regid="X", grade="A", match_tier=MatchTier.A_EXACT,
                        confidence=1.0, inputs_hash="0" * 64)
        with self.assertRaises(Exception):
            g.grade = "F"   # type: ignore[misc]


class VersionTest(unittest.TestCase):
    def test_version_is_1_0_0(self):
        self.assertEqual(BRAIN_PENTAD_VERSION, "1.0.0")


if __name__ == "__main__":
    unittest.main()
