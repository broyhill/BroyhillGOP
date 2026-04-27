"""
e61.datatrust_match — DataTrust match ladder T1..T6 (Phase 2 stub).

T1  literal      norm_last + norm_first + reg_zip5             ← today's stage2_pass1 (87% of existing matches)
T2  mailzip      norm_last + norm_first + mail_zip5            ← catches movers
T3  address-num  norm_last + norm_first + house_number(line_1) ← catches different street spellings
T4  nickname     norm_last + nickname_resolve(first) + reg_zip5 ← unlocks 'ED' → JAMES EDGAR
T5  middle-init  norm_last + first_initial(first) + middle + zip5 ← unlocks 'JAMES E' ↔ 'JAMES EDGAR'
T6  county-anchor zip5 → county_name → SVI prefix narrowing    ← Ed's geographic insight

Each tier is gated on:
    - canary integrity (Ed/Pope/Melanie clusters must remain valid after match)
    - single-unambiguous match (no n_rnc > 1 unless dollar-volume tiebreak applies)
    - suffix compatibility (Sr ≠ Jr blocks merge)
    - non-person filter (corporate token blacklist applied first)

STATUS: stub. Real implementation lands in Phase 2. Until then, the production
matcher is the Stage-2 Python in scripts/committee_donor_*.

DataTrust column reality (per Perplexity 2026-04-27 schema check):
    last_name, first_name, middle_name, name_suffix
    reg_zip5, mail_zip5, county_name, state_county_code
    state_voter_id (2-letter prefix encodes county), rnc_regid
    voter_status ('A' active, 'I' inactive, deceased removed)
"""

from __future__ import annotations

from typing import Any


def match_tier_ladder(rows: list[dict[str, Any]]) -> list[dict[str, Any]]:
    """Phase 2 entry point. Returns rows with rnc_regid_v2, match_tier populated."""
    raise NotImplementedError(
        "E61 DataTrust match ladder is held until Phase 2 implementation."
    )
