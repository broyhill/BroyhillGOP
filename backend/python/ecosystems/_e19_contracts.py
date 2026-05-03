"""
Local Pentad-contract fallback for E19.

Source of truth WILL BE `shared/brain_pentad_contracts.py` once the
Pentad-contracts PR (`claude/brain-pentad-contracts-2026-05-02`) merges to main.
Until then, E19 ships these inline so the module is self-contained.

TODO(2026-05-03): when shared.brain_pentad_contracts is on main, replace every
`from ecosystems._e19_contracts import X` with `from shared.brain_pentad_contracts
import X` and delete this file. The Pydantic shapes here MUST stay in lockstep
with the ones in the Pentad PR.
"""
from __future__ import annotations
from datetime import datetime
from enum import Enum
from typing import Any, Dict, Literal, Optional
from pydantic import BaseModel, Field


BRAIN_PENTAD_VERSION = "1.0.0-e19-local"


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
    SOCIAL_FB        = "social_fb"
    SOCIAL_IG        = "social_ig"
    SOCIAL_X         = "social_x"
    SOCIAL_LINKEDIN  = "social_linkedin"
    SOCIAL_TIKTOK    = "social_tiktok"
    SOCIAL_YOUTUBE   = "social_youtube"


class CostType(str, Enum):
    SEND          = "send"
    PRINT         = "print"
    POSTAGE       = "postage"
    GPU           = "gpu"
    AI_INFERENCE  = "ai_inference"
    DATA_PURCHASE = "data_purchase"
    LABOR         = "labor"
    AD_SPEND      = "ad_spend"
    OTHER         = "other"


GradeLetter = Literal["A", "B", "C", "D", "F"]


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


class SendOutcome(BaseModel):
    send_id: str
    donor_id: str
    channel: Channel
    cost_cents: int = Field(..., ge=0)
    delivered: bool = False
    opened: bool = False
    clicked: bool = False
    revenue_cents: int = Field(0, ge=0)
    fatigue_delta: float = 0.0
    sent_at: datetime
    bounce_type: Optional[Literal["hard", "soft", "none"]] = None
    complaint: bool = False
    unsubscribed: bool = False
    blocked_by: Optional[str] = None
    model_config = {"frozen": True, "use_enum_values": False}


class CostEvent(BaseModel):
    event_id: str = Field(..., min_length=8)
    source_ecosystem: str
    donor_id: Optional[str] = None
    cost_type: CostType
    vendor: str
    unit_cost_cents: int = Field(..., ge=0)
    quantity: int = Field(..., ge=1)
    total_cost_cents: int = Field(..., ge=0)
    revenue_attributed_cents: int = Field(0, ge=0)
    occurred_at: datetime
    model_config = {"frozen": True, "use_enum_values": False}


class RuleFired(BaseModel):
    rule_id: str
    target_ecosystem: str
    action: str
    payload: Dict[str, Any] = Field(default_factory=dict)
    fired_at: datetime = Field(default_factory=datetime.utcnow)
    audit_trail_id: str
    model_config = {"frozen": True, "use_enum_values": False}


__all__ = [
    "BRAIN_PENTAD_VERSION",
    "MatchTier", "Channel", "CostType", "GradeLetter",
    "PersonalizedMessage", "SendOutcome", "CostEvent", "RuleFired",
]
