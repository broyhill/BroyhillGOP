#!/usr/bin/env python3
"""
ECOSYSTEM 19 — Custom Audience Builder

Builds platform-specific custom audiences from internal lists. Sub-weapons:
  E19-Retarget   — custom audience retargeting
  E19-Lookalike  — lookalike audiences seeded from a custom audience

Hard rules:
  - Every audience is keyed on rnc_regid.
  - Individualized audiences are gated by match_tier IN ('A_EXACT', 'B_ALIAS').
    C/D/E/UNMATCHED are excluded from individualized targeting.
  - Email/phone hashing follows each platform's spec (lowercase + trim + SHA-256
    for Meta + Google + X; phone E.164 first; TikTok uses a separate format).
"""
from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import uuid
from dataclasses import dataclass, field
from datetime import datetime
from typing import Iterable, List, Optional, Sequence

import psycopg2
from psycopg2.extras import RealDictCursor, Json

logger = logging.getLogger("ecosystem19.audience_builder")


_INDIVIDUALIZED_TIERS = frozenset({"A_EXACT", "B_ALIAS"})


# ============================================================================
# Audience dataclass
# ============================================================================

@dataclass
class Audience:
    audience_id: str = field(default_factory=lambda: str(uuid.uuid4()))
    candidate_id: str = ""
    audience_type: str = "donor_list"
    source_filter: dict = field(default_factory=dict)
    rnc_regid_count: int = 0
    match_tier_filter: str = "A_EXACT,B_ALIAS"
    platform_uploads: dict = field(default_factory=dict)
    members: List[dict] = field(default_factory=list)  # raw list, never persisted

    def to_meta_format(self) -> List[str]:
        """Hashed lowercased email list (SHA-256 hex), Meta Custom Audience format."""
        return [
            hashlib.sha256(m["email"].strip().lower().encode()).hexdigest()
            for m in self.members
            if m.get("email")
        ]

    def to_google_customer_match(self) -> List[str]:
        """Same shape as Meta — Google Customer Match accepts SHA-256 lowercased email."""
        return [
            hashlib.sha256(m["email"].strip().lower().encode()).hexdigest()
            for m in self.members
            if m.get("email")
        ]

    def to_x_tailored_audience(self) -> List[str]:
        """X Tailored Audience: SHA-256 of lowercased email."""
        return [
            hashlib.sha256(m["email"].strip().lower().encode()).hexdigest()
            for m in self.members
            if m.get("email")
        ]

    def to_tiktok_custom_audience(self) -> List[dict]:
        """TikTok accepts hashed email + hashed phone E.164 in one record per user."""
        out = []
        for m in self.members:
            entry = {}
            if m.get("email"):
                entry["email_sha256"] = hashlib.sha256(
                    m["email"].strip().lower().encode()
                ).hexdigest()
            if m.get("phone"):
                phone = _normalize_phone_e164(m["phone"])
                if phone:
                    entry["phone_sha256"] = hashlib.sha256(phone.encode()).hexdigest()
            if entry:
                out.append(entry)
        return out


def _normalize_phone_e164(phone: str) -> Optional[str]:
    digits = re.sub(r"\D", "", phone or "")
    if len(digits) == 10:
        return f"+1{digits}"
    if len(digits) == 11 and digits.startswith("1"):
        return f"+{digits}"
    if len(digits) >= 7:
        return f"+{digits}"
    return None


# ============================================================================
# CustomAudienceBuilder
# ============================================================================

class CustomAudienceBuilder:
    """Builds audiences from various source types. Persists via .save() to
    core.e19_audiences. Never persists raw member lists (those carry PII)."""

    def __init__(self, db_url: Optional[str] = None,
                 candidate_id: Optional[str] = None):
        self.db_url = db_url or os.getenv("DATABASE_URL",
                                          "postgresql://localhost/broyhillgop")
        self.candidate_id = candidate_id or ""

    def _get_db(self):
        return psycopg2.connect(self.db_url)

    # --- Source: donor list (rnc_regid input)
    def from_donor_list(self, rnc_regids: Sequence[str],
                        match_tier_filter: str = "A_EXACT,B_ALIAS",
                        members: Optional[List[dict]] = None) -> Audience:
        """Build from a list of rnc_regids. `members` is the test injection point —
        if provided, skips the DB read and uses the passed members directly.

        match_tier_filter is comma-separated. Default keeps only A_EXACT + B_ALIAS
        (the individualized-targeting floor). Pass 'A_EXACT' to be stricter.
        """
        allowed_tiers = frozenset(t.strip() for t in match_tier_filter.split(","))
        if not allowed_tiers.issubset(_INDIVIDUALIZED_TIERS):
            # Spec: individualized targeting only A_EXACT/B_ALIAS. Any other tier
            # in the filter is silently dropped here; the gate in
            # ecosystem_19_social_media will block sends regardless.
            allowed_tiers = allowed_tiers & _INDIVIDUALIZED_TIERS

        if members is None:
            members = self._fetch_members(rnc_regids, allowed_tiers)

        # Filter to matched tiers, dedupe by rnc_regid.
        seen = set()
        filtered = []
        for m in members:
            if m.get("rnc_regid") in seen:
                continue
            tier = m.get("match_tier", "UNMATCHED")
            if tier not in allowed_tiers:
                continue
            seen.add(m["rnc_regid"])
            filtered.append(m)

        return Audience(
            candidate_id=self.candidate_id,
            audience_type="donor_list",
            source_filter={"rnc_regid_count_in": len(rnc_regids),
                           "match_tier_filter": match_tier_filter},
            rnc_regid_count=len(filtered),
            match_tier_filter=match_tier_filter,
            members=filtered,
        )

    def _fetch_members(self, rnc_regids: Sequence[str],
                       allowed_tiers: frozenset) -> List[dict]:
        """Load member records from core.donor_profile for the given rnc_regids."""
        if not rnc_regids:
            return []
        conn = self._get_db()
        try:
            with conn.cursor(cursor_factory=RealDictCursor) as cur:
                cur.execute(
                    "SELECT rnc_regid, personal_email AS email, "
                    "       cell_phone AS phone, "
                    "       COALESCE(match_tier, 'UNMATCHED') AS match_tier "
                    "FROM core.donor_profile "
                    "WHERE rnc_regid = ANY(%s)",
                    (list(rnc_regids),),
                )
                return [dict(r) for r in cur.fetchall()]
        finally:
            conn.close()

    # --- Source: web visitors via E56 visitor de-anon
    def from_web_visitors(self, days_back: int,
                          members: Optional[List[dict]] = None) -> Audience:
        """Pull web visitors deanonymized in the last N days from E56.

        Members is the test injection point. In production this hits the
        E56 visitor de-anon view (TODO: implement when E56 is ready).
        """
        if members is None:
            members = []  # Stub until E56 visitor de-anon view exists.
            logger.warning("from_web_visitors: E56 visitor de-anon view not wired yet; "
                           "returning empty audience (backlog)")
        return Audience(
            candidate_id=self.candidate_id,
            audience_type="web_visitors",
            source_filter={"days_back": days_back},
            rnc_regid_count=len(members),
            members=members,
        )

    # --- Source: email engagers
    def from_email_engagers(self, action: str, days_back: int,
                            members: Optional[List[dict]] = None) -> Audience:
        """Pull donors who took a specific email action in the last N days.

        action: 'opened' | 'clicked' | 'replied' | 'unsubscribed'.
        """
        valid = {"opened", "clicked", "replied", "unsubscribed"}
        if action not in valid:
            raise ValueError(f"action must be one of {valid}, got {action}")
        if members is None:
            members = []  # TODO: query email engagement table when wired.
        return Audience(
            candidate_id=self.candidate_id,
            audience_type="email_engagers",
            source_filter={"action": action, "days_back": days_back},
            rnc_regid_count=len(members),
            members=members,
        )

    # --- Lookalike from a seed audience
    def lookalike(self, seed_audience: Audience, similarity: float) -> Audience:
        """Build a lookalike audience seeded from another audience.

        similarity: 0.0–1.0. 0.0 = closest match (smaller pool, higher quality);
        1.0 = broadest pool (lowest similarity per member). Most platforms expose
        this as a 1–10 percentile; we accept 0.0–1.0 and the platform translator
        rounds to that platform's expected scale.
        """
        if not (0.0 <= similarity <= 1.0):
            raise ValueError(f"similarity must be in [0.0, 1.0], got {similarity}")
        # Real lookalike generation is platform-side (Meta builds the model).
        # We persist the request + seed + similarity and let the platform
        # return a populated audience id on upload.
        return Audience(
            candidate_id=self.candidate_id,
            audience_type="lookalike",
            source_filter={"seed_audience_id": seed_audience.audience_id,
                           "similarity": similarity,
                           "seed_size": seed_audience.rnc_regid_count},
            rnc_regid_count=0,  # Populated by platform after upload.
            members=[],
        )

    def save(self, audience: Audience) -> str:
        """Persist the audience metadata (NOT raw members) to core.e19_audiences.
        Returns the audience_id."""
        conn = self._get_db()
        try:
            with conn.cursor() as cur:
                cur.execute(
                    "INSERT INTO core.e19_audiences "
                    "    (audience_id, candidate_id, audience_type, "
                    "     source_filter, rnc_regid_count, match_tier_filter, "
                    "     platform_uploads, created_by) "
                    "VALUES (%s, %s, %s, %s, %s, %s, %s, %s) "
                    "ON CONFLICT (audience_id) DO NOTHING",
                    (audience.audience_id, audience.candidate_id,
                     audience.audience_type, Json(audience.source_filter),
                     audience.rnc_regid_count, audience.match_tier_filter,
                     Json(audience.platform_uploads),
                     "ecosystem_19_audience_builder"),
                )
            conn.commit()
        finally:
            conn.close()
        logger.info(
            f"audience_builder.save {audience.audience_id} type={audience.audience_type} "
            f"count={audience.rnc_regid_count}"
        )
        return audience.audience_id


__all__ = [
    "Audience", "CustomAudienceBuilder",
]
