"""
shared.brain_pentad_contracts — payload schemas for the Brain Pentad.

The five Brain ecosystems (E01 ↔ E19 ↔ E30 ↔ E11 ↔ E60) communicate via a
small, stable, versioned set of Pydantic payloads defined here. The five
ecosystems NEVER import each other; they only import from this module.

This Section-1 commit introduces the first contract:
  - GradedDonor      (E01 → E19): output of E01.grade_donor(rnc_regid)

The remaining five (PersonalizedMessage, SendOutcome, BudgetSignal,
CostEvent, RuleFired, OptimizerDecision) land in the BRAIN_PENTAD_CONTRACTS
PR. This module is the single source of truth for the wire format.

Versioning rule: contract changes require coordinated PR across all five
ecosystems. Bump BRAIN_PENTAD_VERSION below + each affected ecosystem's
version pin. See docs/architecture/BRAIN_PENTAD_CONTRACTS.md (forthcoming).
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Literal

from pydantic import BaseModel, Field


# Coordinated version of the entire Brain Pentad contract suite.
# Bump this on ANY contract change and tag every consuming ecosystem.
BRAIN_PENTAD_VERSION = "1.0.0"


# ============================================================================
# MATCH TIER — donor-spine match quality (used by GradedDonor.match_tier)
# ============================================================================

class MatchTier(str, Enum):
    """
    Confidence that a raw donation row was correctly attributed to a donor.

    Order is best -> worst:

      A_EXACT       — exact rnc_regid + name + DOB + address all line up
      B_ALIAS       — known alias hit (e.g. nickname, maiden name, suffix swap)
      C_FIRST3      — first-3-letters-of-last-name + first-name + zip match
      D_HOUSEHOLD   — same household address, plausible person, no exact match
      E_WRONG_LAST  — last-name mismatch but other strong signals (low confidence)
      UNMATCHED     — no acceptable match found
    """
    A_EXACT      = "A_EXACT"
    B_ALIAS      = "B_ALIAS"
    C_FIRST3     = "C_FIRST3"
    D_HOUSEHOLD  = "D_HOUSEHOLD"
    E_WRONG_LAST = "E_WRONG_LAST"
    UNMATCHED    = "UNMATCHED"


GradeLetter = Literal["A", "B", "C", "D", "F"]


# ============================================================================
# GradedDonor — E01 → E19 contract
# ============================================================================

class GradedDonor(BaseModel):
    """
    Output of E01.grade_donor(rnc_regid).

    Consumed by E19 (personalization) and E11 (budget rollups). E60 observes
    via the cost ledger when grades change ROI assumptions.

    Determinism contract: given the same input row from the trusted/
    needs-review view, grade_donor MUST return the same (grade, match_tier,
    confidence, inputs_hash) tuple. graded_at is metadata only and is NOT
    folded into inputs_hash.
    """
    rnc_regid: str = Field(..., description="Stable donor key from the spine")
    grade: GradeLetter = Field(..., description="A=top quintile … F=do-not-solicit")
    match_tier: MatchTier = Field(..., description="Spine match confidence band")
    confidence: float = Field(..., ge=0.0, le=1.0,
                              description="Combined grade × match confidence, 0–1")
    inputs_hash: str = Field(..., min_length=64, max_length=64,
                             description="SHA-256 of the canonical input JSON; identical inputs MUST produce identical hash")
    graded_at: datetime = Field(default_factory=datetime.utcnow,
                                description="When this grading was computed (metadata; NOT in inputs_hash)")

    model_config = {
        "frozen": True,           # GradedDonor is immutable once computed
        "use_enum_values": False, # Keep enum objects on the wire
    }
