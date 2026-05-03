# BroyhillGOP — Architecture Documentation

Design + rationale docs for the platform's major refactors and new ecosystems.
Read these BEFORE making changes to the corresponding code.

## Section design docs (2026-05-02 cluster)

| Doc | Status | Touches | What it covers |
|---|---|---|---|
| [SECTION_1_E01_GRADING_CONSOLIDATION_DESIGN.md](SECTION_1_E01_GRADING_CONSOLIDATION_DESIGN.md) | PR pushed, NOT merged | E01 | Unified `grade_donor()` + Option-A reorg of 4 support files into `e01_imports/` |
| [SECTION_2_E11B_TRAINING_LMS_DESIGN.md](SECTION_2_E11B_TRAINING_LMS_DESIGN.md) | ✅ MERGED `369d779` | E11, E11B | Renamed Training LMS from `_11_` to `_11b_` (matching its docstring's self-ID) |
| [SECTION_3_E19_SOCIAL_MEDIA_DESIGN.md](SECTION_3_E19_SOCIAL_MEDIA_DESIGN.md) | ✅ MERGED `060ab67` | E19 | Merged 3 files into 1; co-resident SocialMediaEngine + CarouselPostEngine + PlatformPublisher |
| [SECTION_4_E31_SMS_DESIGN.md](SECTION_4_E31_SMS_DESIGN.md) | ✅ MERGED `49ac122` | E31 | TCPA gate; ported ConsentManager + ShortlinkEngine + ABTesting from old `_sms.py` into omnichannel engine |
| [SECTION_5_E16B_VOICE_ULTRA_DESIGN.md](SECTION_5_E16B_VOICE_ULTRA_DESIGN.md) | ✅ MERGED `f914913` | E16B | Verified all 6 voice engines real, not stubs; cleaned 37 lines of duplicate exception classes |
| [SECTION_6_SYNTAX_REPAIR_DESIGN.md](SECTION_6_SYNTAX_REPAIR_DESIGN.md) | ✅ MERGED `d2259cf` | E01 / E36 / E47 / E50 / E53 / E55 | Repaired 6 pre-existing syntax errors from Cursor "Auto-added by repair tool" damage |
| [SECTION_7_E30_EMAIL_ENTERPRISE_DESIGN.md](SECTION_7_E30_EMAIL_ENTERPRISE_DESIGN.md) | PR pushed, NOT merged | E30 | Compliance + spine + Pentad rewrite (CAN-SPAM + FEC + consent + suppression + DKIM/SPF/DMARC + bounce classifier) |
| [SECTION_8_E60_NERVOUS_NET_DESIGN.md](SECTION_8_E60_NERVOUS_NET_DESIGN.md) | PR pushed, NOT merged | E60 (new) + E30/E31 wiring | Cost ledger + IFTTT engine + LP optimizer; **needs DDL authorization** |

## Cross-cutting docs

| Doc | Status |
|---|---|
| [BRAIN_PENTAD_CONTRACTS.md](BRAIN_PENTAD_CONTRACTS.md) | PR pushed, NOT merged |

The Brain Pentad doc is the constitution for the five Brain modules (E01, E19, E30, E11, E60). Read it before touching any of the five.

## How to read these docs

Each design doc has the same shape:

1. **Why this PR existed** — the problem statement.
2. **The decision** — what was picked over what alternatives, and why.
3. **What changed** — concrete file/class diffs.
4. **API surface** — the public entry points after the change.
5. **Integration contract** — how downstream modules consume this.
6. **Tests** — what was tested and what was deliberately NOT tested.
7. **What this PR did NOT change** — explicit scope boundary.
8. **Migration notes** — what breaks if you don't read the doc first.
9. **Known limits** — tracked-but-deferred work.

If you make a change that contradicts any of these design docs, **update the doc in the same PR.** A doc that disagrees with the live code is worse than no doc at all.

---
*Index authored by Claude (Cowork session, Opus 4.7), 2026-05-02.*
