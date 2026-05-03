# Section 1 — E01 Grading Consolidation (Design + Rationale)

**Status:** PR pushed, NOT merged. Branch `claude/section-1-e01-grading-consolidation-2026-05-02` (commit `d2d2717`).
**Brain Pentad role:** E01 — first node in the Pentad linear loop.
**Tests:** 24 unit tests, all passing (`tests/test_e01_determinism.py`, `tests/test_e01_match_tier_passthrough.py`, `tests/test_e01_grade_distribution.py`).

---

## The problem

Five files lived under `ecosystems/ecosystem_01_*.py` — collectively ~10,400 lines of Python — but only one (`ecosystem_01_donor_intelligence.py`) actually graded donors. The other four (data import master, contact file ingest, social OAuth capture, social graph builder) were **support modules with no business being top-level E01 ecosystems.**

Inside `ecosystem_01_donor_intelligence.py` itself, grading was scattered across multiple classes: `ThreeDGradingEngine` (3D Amount × Intensity × Level), `RFMAnalyzer` (RFM separately), `GradeEnforcement` (action gating), and inside `DonorIntelligenceSystem.score_donor()`. There was no single function that any other ecosystem could call to "get a donor's grade."

The Brain Pentad architecture (Section 3 of this doc cluster) requires E01 to emit a single canonical `GradedDonor` payload. Without a unified `grade_donor()` entry point, every Brain consumer would be reverse-engineering E01's internals.

## Decision (Option A from the assignment doc)

**Picked Option A:** Keep `ecosystem_01_donor_intelligence.py` as canonical E01. Move the four support files to `ecosystems/e01_imports/` with cleaner, no-E-prefix names. Add a single new `grade_donor(rnc_regid)` function as the unified public API.

**Option B (split into separate ecosystems E02a/b/c/d)** was rejected because it would conflict with the existing E02 (Donation Processing) and force a renumber chain across the entire downstream architecture skill, dependency graph, and Hetzner registry. Option A is contained.

## What changed

### File reorganization (Option A)

| Old path | New path |
|---|---|
| `ecosystems/ecosystem_01_data_import_engine.py` | `ecosystems/e01_imports/data_import_master.py` |
| `ecosystems/ecosystem_01_contact_import.py` | `ecosystems/e01_imports/contact_file_ingest.py` |
| `ecosystems/ecosystem_01_social_oauth_maximum_capture.py` | `ecosystems/e01_imports/social_oauth_capture.py` |
| `ecosystems/ecosystem_01_platform_social_import.py` | `ecosystems/e01_imports/social_graph_builder.py` |

`ecosystems/ecosystem_01_donor_intelligence.py` stayed in place as the canonical E01.

### New unified grading API

```python
from ecosystem_01_donor_intelligence import grade_donor
from shared.brain_pentad_contracts import GradedDonor, MatchTier

result: GradedDonor = grade_donor("RNC-372171-ED-BROYHILL")
# GradedDonor(
#     rnc_regid="RNC-372171-ED-BROYHILL",
#     grade="A",
#     match_tier=MatchTier.A_EXACT,
#     confidence=0.97,
#     inputs_hash="3f2b8c...64chars",
#     graded_at=datetime(2026, 5, 2, 23, 5, 12, ...),
# )
```

The function's signature:

```python
def grade_donor(rnc_regid: str,
                db_url: Optional[str] = None,
                row: Optional[dict] = None) -> GradedDonor:
```

`row` is a test injection point — passing a pre-fetched row dict bypasses the DB read. In production, `row=None` triggers a SELECT against `core.v_donor_profile_trusted` (78,037 rows expected) then `core.v_donor_profile_needs_review` (2,568 rows expected) until the donor is found or both views are exhausted.

### Determinism contract

Given the same input row, `grade_donor` MUST return the same `(grade, match_tier, confidence, inputs_hash)` tuple. `graded_at` is metadata only and is **NOT** folded into `inputs_hash`.

The `inputs_hash` is a SHA-256 of canonical JSON over a fixed projection:

```python
_GRADE_INPUT_FIELDS = (
    "rnc_regid", "txn_count", "lifetime_total", "largest_gift",
    "first_gift_date", "last_gift_date",
    "committee_count", "candidate_count", "match_tier",
)
```

Adding/removing any field in this tuple is a **breaking change** to the determinism contract. Bump `BRAIN_PENTAD_VERSION` if you change it.

### Composite scoring

`_composite_score(row) → 0–100 float`. Pure function (no DB, no time, no random). Components:

- **Amount (0–50):** `min(50, math.log10(lifetime_total + 1) * 8.0)`. Calibrated so $1M lifetime ≈ 48; $5K ≈ 30; $50 ≈ 14.
- **Engagement (0–30):** `min(30, txn_count * 1.5 + candidate_count * 2.0)`.
- **Recency (0–20):** Days since 2025-01-01 (a deterministic anchor — NOT "now"). Each 30 days adds 1 point, capped at 20.

### Score → letter mapping

```
A: score ≥ 80
B: score ≥ 60
C: score ≥ 40
D: score ≥ 20
F: otherwise
```

### Confidence

`confidence = round(min(1.0, max(0.0, tier_floor * grade_clarity)), 4)` where:

- `tier_floor`: A_EXACT=1.00, B_ALIAS=0.90, C_FIRST3=0.75, D_HOUSEHOLD=0.55, E_WRONG_LAST=0.25, UNMATCHED=0.0
- `grade_clarity`: 0.5 + 0.5 × (distance from score 50). Confidence is highest near the extremes (clear A or clear F), softer in the middle.

So an A_EXACT row scoring 95 has confidence ≈ 0.95; an A_EXACT row scoring 51 has confidence ≈ 0.50; a D_HOUSEHOLD row scoring 95 has confidence ≈ 0.52.

## Cleanup that came along (incidental but required)

`ecosystem_01_donor_intelligence.py` had two duplicate Cursor "Auto-added by repair tool" exception class blocks **inside** the `if __name__ == "__main__":` block. The CLI dispatcher (`if len(sys.argv) > 1 and sys.argv[1] == "--deploy":`) was getting **swallowed into the last exception class body** because Python's parser interpreted the indent-4 code as continuation of the class block. Result: `NameError: name 'sys' is not defined` at module import time.

Same recipe as Section 6: stripped both injection blocks, added one canonical exception block at module level. Now the file imports cleanly.

## What this PR did NOT change

- The internal grading classes (`ThreeDGradingEngine`, `RFMAnalyzer`, `GradeEnforcement`, `DonorIntelligenceSystem.score_donor`). They stay as internal implementation details. No deprecation warnings yet — flagged for a follow-up cleanup.
- The donor view schema. `core.v_donor_profile_trusted` and `core.v_donor_profile_needs_review` are read-only consumers.
- The `core.donor_profile` table or any other write target. **E01 is read-only after this PR.**
- The four support modules (now under `e01_imports/`). They retained their full code; only the file path changed.

## Brain Pentad integration

E01 → E19. After this PR + the Pentad PR, E19 personalization will receive `GradedDonor` payloads as input. Today, E19 still uses its existing brain-event subscription. Wiring E01 → E19 to use the Pentad payload is a follow-up.

## Tests (24 total)

**`test_e01_determinism.py` (5):** Identical input → identical hash + grade + tier + confidence. `graded_at` is NOT in inputs_hash. Changing `lifetime_total` by one cent changes hash. Changing fields outside `_GRADE_INPUT_FIELDS` does NOT change hash. `inputs_hash` is 64-char SHA-256 hex.

**`test_e01_match_tier_passthrough.py` (11):** All 6 match_tier values pass through verbatim. Missing → UNMATCHED. Invalid → UNMATCHED. row=None → F + 0.0 confidence + UNMATCHED. A_EXACT confidence > D_HOUSEHOLD confidence (orthogonal axes test). Tier change does NOT change grade letter.

**`test_e01_grade_distribution.py` (8):** $500K megadonor → A. $5K mid-donor → B/C. $50 → D/F. $0 lifetime → F. row=None (mocked) → F. All 5 grades appear in 200-donor synthetic distribution. No grade dominates >70%. Higher lifetime correlates with higher grade.

## Known limits

- The composite scoring weights (8.0 for amount, 1.5 for txn_count, etc.) are hand-calibrated. The synthetic test population is the only evidence the calibration is reasonable. Real-data calibration against the 80K-donor population should happen before Section 1 ships to a live candidate.
- The "recency anchor" of 2025-01-01 is a deterministic hack to keep grading reproducible across runs. A real production version should anchor against the dataset's own "max(last_gift_date)" — but that's harder to make deterministic (re-running on a refreshed dataset would return different grades). Current approach trades dataset-relative recency for reproducibility.
- E01 doesn't yet emit a `BudgetSignal`-driven recalibration. The Pentad spec includes E11 → E01 feedback to recalibrate; consuming that feedback is a follow-up.

---
*Authored by Claude (Cowork session, Opus 4.7), 2026-05-02. PR pushed but NOT merged.*
