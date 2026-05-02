# Claude Assignment — Internal Ecosystem Revisions

**Owner:** Ed Broyhill
**Created by:** Nexus (Perplexity), 2026-05-02
**Branch context:** Apply on top of `fix/rename-and-cleanup-2026-05-02` after merge to main
**Estimated total effort:** 6–10 hours of focused engineering

---

## What's already done (don't redo)

The rename branch (`fix/rename-and-cleanup-2026-05-02`) already:

- Stripped `_complete` from 119 ecosystem Python filenames in `ecosystems/` and `backend/python/ecosystems/`
- Promoted `ecosystem_16b_voice_synthesis_ULTRA_complete.py` (the 26-class masterpiece — F5-TTS, StyleTTS2, Fish Speech, OpenVoice, Bark, neural enhancer, audio super-resolution) to `ecosystem_16b_voice_synthesis_ULTRA.py`
- Deleted 6 superseded/dead files (4 dual_grading error stubs, 2 older E16b drafts)
- Rewrote 476 internal references across 89 files (Python imports, shell scripts, docs, HTML, SQL, USAGE comments)
- Fixed 3 broken `requirements.txt` references (Dockerfiles + deploy script — Cursor damage from 2026-04-08)
- Fixed 536 invalid Python class names (Cursor "Auto-added by repair tool" generated `class 20IntelligenceBrainCompleteError` — illegal Python because identifiers cannot start with a digit; all prefixed with `E`)

**Result:** 137 of 143 ecosystem `.py` files now parse with `ast.parse` cleanly. 6 remaining syntax errors are pre-existing bugs that the rename exposed — they're listed in Section 6 below.

---

## Section 1 — E01 Donor Intelligence: 5 engines, 1 ecosystem

### Problem

`ecosystems/` currently contains 5 different Python files all claiming to be E01:

| File | Lines | What it actually does |
|---|---:|---|
| `ecosystem_01_data_import_engine.py` | 2,471 | Import config, ToggleState, AccessLevel, FunctionCategory, ControlToggle, MasterControl, ImportRecord — appears to be a **master import controller** |
| `ecosystem_01_donor_intelligence.py` (post-rename) | 1,514 | DonorConfig, GradeViolationError, ThreeDGradingEngine, RFMScore, DonorGrade, LifecycleStage — the **canonical E01** per architecture skill |
| `ecosystem_01_social_oauth_maximum_capture.py` | 2,055 | SocialConfig, Platform, BaseSocialHandler, FacebookHandler, InstagramHandler — **OAuth/social capture engine**, not donor intel |
| `ecosystem_01_contact_import.py` | 1,902 | VCardParser, OutlookContactsParser, GoogleContactsParser, MobileShareHandler — **contact-file ingest** |
| `ecosystem_01_platform_social_import.py` | 1,463 | OAuthCredentials, SocialGraphEngine — **social graph builder**; ⚠️ has pre-existing syntax error at line 1411 |

This isn't 1 ecosystem with 5 versions. It's **5 distinct engines** crammed under E01.

### Decision needed (Ed)

Option A — Consolidate into one E01:
- Rename `ecosystem_01_donor_intelligence.py` → THE E01
- Move others to a sub-folder `ecosystems/e01_imports/` with no E-number prefix:
  - `e01_imports/data_import_master.py`
  - `e01_imports/contact_file_ingest.py`
  - `e01_imports/social_oauth_capture.py`
  - `e01_imports/social_graph_builder.py`

Option B — Split into separate ecosystems (requires architecture skill update):
- E01 = donor intelligence (3D grading)
- E02a = data import master (currently E01)
- E02b = contact file ingest
- E02c = social OAuth capture
- E02d = social graph builder
- (Conflicts with existing E02 Donation Processing — would need renumbering)

**Nexus recommendation: Option A.** Less renumbering pain, preserves the architecture-skill claim that E01 = Donor Intelligence.

### Claude's task (after Ed picks Option A or B)

1. Read all 5 files end-to-end
2. Identify shared imports, shared classes, shared constants — propose what to keep at top level vs move to `_shared/`
3. Audit cross-file imports: does anything in the platform import any of these by their old name? (cross-check with `BroyhillGOP_Ecosystem_Agent_Registry.xlsx`)
4. Produce a migration script that moves files + updates imports in a single atomic commit
5. Run `ast.parse` + `pyflakes` on every moved file before committing
6. Update `MASTER_DIRECTORY_INDEX.md`, `docs/BROYHILLGOP_COMPLETE_ECOSYSTEM_INVENTORY.md`, and the architecture skill so all references match the new layout

**Effort:** 2–3 hours

---

## Section 2 — E11: Budget Management vs Training LMS

### Problem

Architecture skill says E11 = Budget Management. But after the rename, two files exist:

| File | Lines | Real content |
|---|---:|---|
| `ecosystem_11_budget_management.py` | 937 | BudgetConfig, BudgetLevel, ExpenseCategory, BudgetStatus, BudgetManagementEngine — matches architecture skill |
| `ecosystem_11_training_lms.py` | 1,082 | TrainingConfig, CourseCategory, ContentType, CertificationType, EnrollmentStatus, TrainingLMS — completely different ecosystem |

**Nexus read:** Cursor (or some prior AI) crammed Training/LMS into the E11 slot. Training is real functionality the platform needs, but it shouldn't share an E-number with Budget.

### Decision needed (Ed)

Option A — Make Training a new ecosystem:
- Keep `ecosystem_11_budget_management.py` as the canonical E11
- Move `ecosystem_11_training_lms.py` → new ecosystem (E62 candidate? or E64?)

Option B — Demote Budget if Training LMS is the actual built ecosystem:
- Look at what code actually imports E11 today → that tells you which one is "live"
- The other one becomes the new ecosystem

### Claude's task

1. Run `grep -rn "ecosystem_11" --include="*.py" --include="*.html" --include="*.sh" --include="*.sql"` and classify which file is actually wired up in production
2. Report findings to Ed; he picks the new E-number for the displaced one
3. Apply the renumbering with full reference rewrite + architecture skill update

**Effort:** 1 hour

---

## Section 3 — E19 Social Media: 3 live files, 1 dead, fragmented

### Problem

Currently in `ecosystems/`:

| File | Lines | Brain hooks | Notes |
|---|---:|:---:|---|
| `ecosystem_19_social_media_integration_patch.py` | 1,066 | 🧠 yes | Newest (Apr); has voice/video clients to E16b/E45 |
| `ecosystem_19_social_media_enhanced.py` | 1,142 | no | Full social engine: SocialConfig, Platform, PostType, MediaType, CarouselSlide |
| `ecosystem_19_social_media_manager.py` | 903 | 🧠 yes | Older manager; SocialMediaManager class is the entry point |
| `ecosystem_19_personalization_engine.py` | (deleted) | — | Was 828 lines of error stubs only |

`_integration_patch` calls itself a "patch" in its filename, suggesting it was meant to extend `_manager`, not replace it. But `_enhanced` has the actual carousel/media/RCS class library that neither of the others has.

### Claude's task — REAL ENGINEERING WORK

1. Read all 3 files end-to-end
2. Build a feature matrix: what each provides (publish to FB? IG? carousel? video upload? brain-event subscription?)
3. Pick `_integration_patch` as the surviving filename (`ecosystem_19_social_media.py`) and **merge** all unique features from `_enhanced` and `_manager` into it:
   - `_enhanced` carousel classes
   - `_enhanced` MediaType enum
   - `_manager` SocialMediaManager entry point (rename to `SocialMediaEngine`)
4. Delete the 2 source files after merge
5. Add `tests/test_e19_social_media.py` with smoke tests for each platform handler
6. Verify with `python3 -m py_compile` and a manual import in a fresh Python process

**Effort:** 1–2 hours. **High risk** — this is a real merge, not a rename.

---

## Section 4 — E31 SMS: Two engines, one is RCS-omnichannel, one has shortlink+consent

### Problem

| File | Lines | Provides |
|---|---:|---|
| `ecosystem_31_sms_enhanced.py` | 1,344 | Omnichannel (SMS+RCS), MessagingConfig, MessageChannel, ResponseSentiment |
| `ecosystem_31_sms.py` (post-rename, was `_sms_complete`) | 861 | SMSConfig, SMSProvider, ShortlinkEngine, ConsentManager, SMSABTestingEngine |

`_enhanced` is the architectural superset (RCS = upgrade beyond SMS). But `_complete` has **shortlink + consent + A/B testing** code that isn't in `_enhanced`.

### Claude's task

1. Read both files
2. Extract `ShortlinkEngine`, `ConsentManager`, `SMSABTestingEngine` from `_sms.py` and **port them into `_sms_enhanced.py`**
3. Validate that consent enforcement (TCPA/10DLC compliance) is preserved — this is non-negotiable per `ethical-guardrails` skill
4. Rename `_sms_enhanced.py` → `ecosystem_31_sms.py` (replacing the older one)
5. Delete the old `_sms.py`
6. Add unit tests for consent manager: `test_consent_blocks_optout`, `test_shortlink_url_canonicalization`

**Effort:** 1 hour. **Compliance-sensitive** — TCPA violation = real money penalty.

---

## Section 5 — E16b Voice Ultra: cleanup is done, but verify provider stubs

### Status

`ecosystems/ecosystem_16b_voice_synthesis_ULTRA.py` is now the **single masterpiece file** (2,208 lines, 26 classes, ULTRA edition with neural enhancement).

### Claude's optional cleanup task

1. Read the file end-to-end
2. The 4 newer engine classes (F5TTSEngine, StyleTTS2Engine, FishSpeechEngine, OpenVoiceEngine) — verify they're not stubs. If they are stubs that just `raise NotImplementedError`, document what real implementation each needs (model weights download, GPU config, voice cloning training set).
3. Document the GPU memory footprint — XTTS + Bark + F5-TTS together require ~24GB VRAM minimum. Ed's Hetzner box is CPU. Note where these will run vs E50 GPU Orchestrator.

**Effort:** 1 hour. Low risk.

---

## Section 6 — Pre-existing syntax errors (NOT caused by rename)

These 6 files do not parse with `ast.parse`. All errors pre-exist on `main`. None are import targets in production today (which is why they've gone unnoticed). All 6 were touched by Cursor's "Auto-added by repair tool" comment block — same source as the 536 broken class names already fixed.

| File | Line | Error | Likely cause |
|---|---:|---|---|
| `ecosystems/ecosystem_01_platform_social_import.py` | 1411 | unexpected indent | Block re-indented inside removed `if` |
| `ecosystems/ecosystem_47_unified_voice_engine.py` | 359 | unexpected indent | Same pattern |
| `ecosystems/ecosystem_50_gpu_orchestrator.py` | 1150 | invalid syntax in `print("""...` | Triple-quote string broken across edits |
| `ecosystems/ecosystem_53_document_generation.py` | 675 | expected `except` or `finally` | Cursor injected `# === CONFIGURATION MANAGEMENT ===` block inside an unclosed `try:` |
| `ecosystems/ecosystem_55_api_gateway.py` | 465 | unexpected indent | Same indent pattern as 47 |
| `backend/python/ecosystems/ecosystem_36_messenger_integration.py` | 6 | unexpected indent at start of file | Cursor stripped wrapping function/class def |

### Claude's task

For each file:
1. Compare against its sibling in the other dir (`ecosystems/` ↔ `backend/python/ecosystems/`) — one may be the un-corrupted twin
2. If both are corrupted, reconstruct from class structure context — these files are mostly intact, they just have a few mis-edited blocks
3. Run `ast.parse` after every fix
4. Add a comment header `# Repaired 2026-05-XX after Cursor 'Auto-added by repair tool' damage`

**Effort:** 1–2 hours total.

---

## Order of operations (recommended)

1. **Ed merges `fix/rename-and-cleanup-2026-05-02` to main** (Nexus's branch — already prepared)
2. **Claude tackles Section 6 first** (smallest, unblocks `import ecosystems.ecosystem_55_api_gateway` etc. for any code that needs it)
3. **Claude does Sections 2 + 5** (E11 disambiguation + E16b verification — quick)
4. **Claude does Section 4** (E31 SMS merge — compliance-sensitive, do while focused)
5. **Claude does Section 3** (E19 social media merge — biggest single merge)
6. **Claude does Section 1** (E01 — needs Ed architectural decision first)

---

## Acceptance criteria

For each section's PR:

- [ ] All ecosystem `.py` files in scope pass `ast.parse`
- [ ] No new broken references (use the daily 8 AM cron `BroyhillGOP rename scan` to verify before pushing)
- [ ] `MASTER_DIRECTORY_INDEX.md` updated
- [ ] `docs/BROYHILLGOP_COMPLETE_ECOSYSTEM_INVENTORY.md` updated
- [ ] Architecture skill (`broyhillgop-architecture`) updated if E-numbers change
- [ ] PR description includes before/after class diagrams for any merge
- [ ] Smoke test added for any new merged engine
- [ ] No DDL changes (no new database tables) without separate `I AUTHORIZE THIS ACTION` from Ed
- [ ] Commit author = Claude or Cursor (NOT "Ed Broyhill")

---

## Out of scope (keep separate)

- The `feat/meta-tech-provider-step5b` branch (119 files / 12,986 lines unmerged) — needs a separate decision
- The duplicate-folder problem: `ecosystems/` vs `backend/python/ecosystems/` (one is canonical, the other stale — needs separate cleanup pass)
- E60 design conflict: Poll/Survey vs Addiction Psychology — Ed needs to pick before E60 is built
- Leaked Supabase password `ZODTJq9BAtAq0qYF` on public repo — rotate separately
- Mac Finder duplicates (`* 2.py`, `* 2.docx`, `* 3.xlsx`) — separate cleanup pass

---

*Authored by Nexus, 2026-05-02 16:50 EDT.*
*Source-of-truth branch: `fix/rename-and-cleanup-2026-05-02` head `520399f`.*
