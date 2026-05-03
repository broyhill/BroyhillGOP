"""
shared.brain_pentad_contracts — payload schemas for the Brain Pentad.

The five Brain ecosystems (E01 ↔ E19 ↔ E30 ↔ E11 ↔ E60) communicate via a
small, stable, versioned set of Pydantic v2 payloads defined here. The five
ecosystems NEVER import each other; they only import from this module.

CONSTITUTION (see docs/architecture/BRAIN_PENTAD_CONTRACTS.md for the full
text and diagrams):

  Linear loop:   E01 → E19 → E30 → E11 → feedback to E01
  Nervous net:   E60 is peer to all four — observes every event, fires rules,
                 runs the optimizer.

VERSION RULE: bump BRAIN_PENTAD_VERSION on any contract change. Coordinate
the bump across PRs in all five ecosystems.

DETERMINISM: all payloads are frozen Pydantic models (immutable after
construction). The wire format is JSON via .model_dump_json().
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Any, Dict, List, Literal, Optional

from pydantic import BaseModel, Field, model_validator


BRAIN_PENTAD_VERSION = "1.0.0"


# ============================================================================
# SHARED ENUMS
# ============================================================================

class MatchTier(str, Enum):
    A_EXACT      = "A_EXACT"
    B_ALIAS      = "B_ALIAS"
    C_FIRST3     = "C_FIRST3"
    D_HOUSEHOLD  = "D_HOUSEHOLD"
    E_WRONG_LAST = "E_WRONG_LAST"
    UNMATCHED    = "UNMATCHED"


class Channel(str, Enum):
    EMAIL    = "email"
    SMS      = "sms"
    MMS      = "mms"
    RCS      = "rcs"
    WHATSAPP = "whatsapp"
    VOICE    = "voice"
    DIRECT_MAIL = "direct_mail"


class CostType(str, Enum):
    SEND          = "send"
    PRINT         = "print"
    POSTAGE       = "postage"
    GPU           = "gpu"
    AI_INFERENCE  = "ai_inference"
    DATA_PURCHASE = "data_purchase"
    LABOR         = "labor"
    OTHER         = "other"


GradeLetter = Literal["A", "B", "C", "D", "F"]


# ============================================================================
# GradedDonor — E01 → E19
# ============================================================================

class GradedDonor(BaseModel):
    """Output of E01.grade_donor(rnc_regid). See docs for full spec."""
    rnc_regid: str = Field(...)
    grade: GradeLetter = Field(...)
    match_tier: MatchTier = Field(...)
    confidence: float = Field(..., ge=0.0, le=1.0)
    inputs_hash: str = Field(..., min_length=64, max_length=64)
    graded_at: datetime = Field(default_factory=datetime.utcnow)

    model_config = {"frozen": True, "use_enum_values": False}


# ============================================================================
# PersonalizedMessage — E19 → E30
# ============================================================================

class PersonalizedMessage(BaseModel):
    donor_id: str = Field(..., description="rnc_regid of the recipient")
    variant_id: str = Field(...)
    channel: Channel = Field(...)
    subject: Optional[str] = Field(None)
    body: str = Field(...)
    cta_url: Optional[str] = Field(None)
    expires_at: datetime = Field(...)
    grade_at_personalization: GradeLetter = Field(...)
    match_tier: MatchTier = Field(...)

    model_config = {"frozen": True, "use_enum_values": False}


# ============================================================================
# SendOutcome — E30/E31/E32 → E11
# ============================================================================

class SendOutcome(BaseModel):
    send_id: str = Field(...)
    donor_id: str = Field(..., description="rnc_regid of the recipient")
    channel: Channel = Field(...)
    cost_cents: int = Field(..., ge=0)
    delivered: bool = Field(False)
    opened: bool = Field(False)
    clicked: bool = Field(False)
    revenue_cents: int = Field(0, ge=0)
    fatigue_delta: float = Field(0.0)
    sent_at: datetime = Field(...)
    bounce_type: Optional[Literal["hard", "soft", "none"]] = Field(None)
    complaint: bool = Field(False)
    unsubscribed: bool = Field(False)

    model_config = {"frozen": True, "use_enum_values": False}


# ============================================================================
# BudgetSignal — E11 → E01
# ============================================================================

class BudgetSignal(BaseModel):
    period: Literal["1d", "7d", "30d", "90d"] = Field(...)
    per_grade_roi: Dict[GradeLetter, float] = Field(...)
    per_tier_roi: Dict[MatchTier, float] = Field(...)
    reallocation_flags: List[str] = Field(default_factory=list)
    computed_at: datetime = Field(default_factory=datetime.utcnow)

    model_config = {"frozen": True, "use_enum_values": False}


# ============================================================================
# CostEvent — any Brain module → E60
# ============================================================================

class CostEvent(BaseModel):
    event_id: str = Field(..., min_length=8)
    source_ecosystem: str = Field(...)
    donor_id: Optional[str] = Field(None)
    cost_type: CostType
    vendor: str = Field(...)
    unit_cost_cents: int = Field(..., ge=0)
    quantity: int = Field(..., ge=1)
    total_cost_cents: int = Field(..., ge=0)
    revenue_attributed_cents: int = Field(0, ge=0)
    occurred_at: datetime = Field(...)

    model_config = {"frozen": True, "use_enum_values": False}

    @model_validator(mode="after")
    def _check_total_matches_unit_quantity(self):
        expected = self.unit_cost_cents * self.quantity
        if self.total_cost_cents != expected:
            raise ValueError(
                f"total_cost_cents ({self.total_cost_cents}) must equal "
                f"unit_cost_cents ({self.unit_cost_cents}) * quantity ({self.quantity}) "
                f"= {expected}"
            )
        return self


# ============================================================================
# RuleFired — E60 → any Brain module
# ============================================================================

class RuleFired(BaseModel):
    rule_id: str = Field(...)
    target_ecosystem: str = Field(...)
    action: str = Field(...)
    payload: Dict[str, Any] = Field(default_factory=dict)
    fired_at: datetime = Field(default_factory=datetime.utcnow)
    audit_trail_id: str = Field(...)

    model_config = {"frozen": True, "use_enum_values": False}


# ============================================================================
# OptimizerDecision — E60 → E11
# ============================================================================

class OptimizerDecision(BaseModel):
    allocations: List[Dict[str, Any]] = Field(...)
    expected_revenue_cents: int = Field(..., ge=0)
    constraints_satisfied: bool = Field(...)
    model_version: str = Field(...)
    decided_at: datetime = Field(default_factory=datetime.utcnow)

    model_config = {"frozen": True, "use_enum_values": False}


__all__ = [
    "BRAIN_PENTAD_VERSION",
    "MatchTier", "Channel", "CostType", "GradeLetter",
    "GradedDonor", "PersonalizedMessage", "SendOutcome",
    "BudgetSignal", "CostEvent", "RuleFired", "OptimizerDecision",
]
