# Section 2 — E11 Budget vs Training LMS Disambiguation (Design + Rationale)

**Merged:** 2026-05-02 as commit `369d779` into `main`.
**Branch:** `claude/section-2-e11b-training-lms-rename-2026-05-02` (now defunct).
**Files touched:** 9 (2 file renames + 7 doc/SQL updates, 20 insertions, 22 deletions).

---

## The problem

Two distinct ecosystems were sharing the E11 slot:

- `ecosystems/ecosystem_11_budget_management.py` — `BudgetManagementEngine` (937 lines). Matches the architecture skill's claim that E11 = Budget Management.
- `ecosystems/ecosystem_11_training_lms.py` — `TrainingLMS` (1,082 lines). Volunteer/staff training, courses, certifications, gamification.

Both were named with the `_11_` prefix. There was no way to tell which one the platform considered "real" E11.

## The smoking gun

The training file's own docstring (line 23) read:

> "Note: Original E11 was Budget Management. This is E11B - Training LMS."

The file already self-identified as E11B. The filename had just never been corrected to match.

## Decision: rename to `_11b_`, not promote to `_62_`

Two options were on the table per the assignment doc:

**Option A:** Rename `ecosystem_11_training_lms.py` → `ecosystem_11b_training_lms.py`. Use the suffix pattern (matching existing `ecosystem_16b_voice_synthesis_ULTRA.py` precedent). E11 stays Budget; E11B becomes Training.

**Option B:** Move Training to a new ecosystem (E62 candidate). Conflicts with existing E02 Donation Processing and would force a renumber chain.

**Picked A** for three reasons:

1. The file already self-identifies as E11B in its docstring. The filename was the only thing out of step.
2. The `E##b` suffix pattern is established (cf. `ecosystem_16b_*`). Using it here is consistent.
3. No new E-number means **zero downstream renumbering** on the architecture skill, dependency graphs, or the Hetzner registry. Option B would have cascaded into 6+ docs and the SQL registry.

## What changed

**File renames (both folders):**
- `ecosystems/ecosystem_11_training_lms.py` → `ecosystems/ecosystem_11b_training_lms.py`
- `backend/python/ecosystems/ecosystem_11_training_lms.py` → `backend/python/ecosystems/ecosystem_11b_training_lms.py`

**Self-references inside the renamed file:** the deploy banner (`print("  python ecosystem_11_training_lms.py --deploy")`) was updated to reference the new filename.

**SQL registry update** (`database/hetzner/102_HETZNER_ECOSYSTEM_REGISTRY.sql`): added one row for E11B right after the E11 row. This is a **data INSERT only** with `ON CONFLICT (ecosystem_code) DO NOTHING` — safe to re-run, **NOT a DDL change**. The `platform.ecosystems` table itself was untouched.

**Comment update** in `database/schemas/COMPLETE_ALL_49_ECOSYSTEMS.sql`: `FROM: ecosystem_11_training_lms.py (E11)` → `FROM: ecosystem_11b_training_lms.py (E11B)`.

**Doc updates** in 6 manual files (auto-generated indices like `god_file_search_index.json` and `GOD_FILE_INDEX_V*.html` were intentionally left alone — they regenerate from the next pipeline run):

- `MASTER_DIRECTORY_INDEX.md` (root)
- `docs/MASTER_DIRECTORY_INDEX.md`
- `docs/BROYHILLGOP_COMPLETE_ECOSYSTEM_INVENTORY.md` (also promoted E11B from "Variant" to its own row)
- `docs/ECOSYSTEM_COMPLETION_TRACKER.md`
- `docs/00_MASTER_HANDOFF_COMPLETE.md`
- `docs/MASTER_CONTEXT.md`

Two dead doc rows referencing the deleted `ecosystem_11_budget_dual_grading.py` (which Nexus's rename branch had already deleted as part of the 4 dual_grading stub cleanup) were also dropped.

## What this PR did NOT change

- `docs/CLAUDE_ASSIGNMENT_2026-05-02.md` — historical record; references the pre-rename name as written.
- `ECOSYSTEM_GAP_ANALYSIS 2.md` — Mac Finder duplicate, out-of-scope.
- Other ecosystems' lingering `_complete.py` doc references — separate cleanup pass.
- Any code logic in either E11 or E11B. Pure rename + reference rewrite.

## API surface

E11 (Budget Management):
```python
from ecosystem_11_budget_management import BudgetManagementEngine
engine = BudgetManagementEngine(...)
```

E11B (Training LMS):
```python
from ecosystem_11b_training_lms import TrainingLMS
lms = TrainingLMS(...)
```

These are separate ecosystems with separate database tables, separate API endpoints, separate purposes. Don't confuse them.

## Migration notes

If any code was importing `ecosystem_11_training_lms` by the old name, it will break. **Verified before merge** that no Python `import` or `from` statements anywhere in the repo referenced the old training filename. Auto-generated indices (god_file, search_results, etc.) will refresh on the next pipeline run.

## Known limits

- The Hetzner registry now has an E11B row, but the platform.ecosystems table on the live Hetzner DB does NOT yet have that row (the SQL file only takes effect on re-run). To bring the live DB into sync, someone needs to apply the registry SQL — but that's just a single `INSERT INTO platform.ecosystems` with ON CONFLICT, so it's safe to apply at any time.
- The duplicate-folder problem (`backend/python/ecosystems/` vs `ecosystems/`) is still present. Section 2 maintained the duplication for E11B (mirrored the rename to both folders) for consistency, but the underlying issue is out-of-scope per the assignment doc.

---
*Authored by Claude (Cowork session, Opus 4.7), 2026-05-02. Rename merged via `369d779`.*
