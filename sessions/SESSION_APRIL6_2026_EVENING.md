# BroyhillGOP Session Transcript — April 6, 2026 Evening
**Perplexity-Claude | Ed Broyhill | NC National Committeeman**
**Session: Monday April 6, 2026 — 7:49 PM to 9:55 PM EDT**

---

## CRITICAL LESSONS FROM THIS SESSION

**Read this section first. These are the things Perplexity got wrong tonight and got corrected on.**

1. **I declared the NCBOE files needed to be loaded — they were already installed.** The 338,223 rows in `public.nc_boe_donations_raw` are a fully processed, normalized, voter-file-synced, DataTrust-synced installation. 3 days of prior work. Sacred. Do not touch.

2. **I proposed replacing the NCBOE dataset with 19 workspace files.** This was wrong. The workspace files are separate pulls not yet evaluated for whether they add to or conflict with the installed dataset.

3. **I used the wrong rollup script (083_match_fec_to_spine_v3.sql) when the correct process is `pipeline/identity_resolution.py` phases A-G2 with the 7-pass DataTrust anchor strategy from `sessions/2026-03-31_DONOR_ROLLUP_IDENTITY_SPEC.md`.**

4. **I declared the database "finished" after stamping party flags and fixing aggregates — without knowing that 779,182 FEC rows have zero person_id and are completely unlinked to THE PEARL.**

5. **I did not know the 8-stage master deployment plan existed (`sessions/2026-04-02_MASTER_DEPLOYMENT_INSTRUCTIONS.md`) until Ed pointed it out.**

6. **I did not know that `public.nc_boe_donations_raw` has `member_id` and `golden_record_id` columns, both 100% populated.**

7. **I did not know the 4 NCBOE candidate/committee scripts are NCBOE-only.** No equivalent FEC candidate/committee matching pipeline exists.

8. **The rule: Do not guess the pipeline. Read the spec first. Ask before assuming.**

---

## WHAT WAS ACTUALLY ACCOMPLISHED TONIGHT

### ✅ Completed

| Action | Detail |
|--------|--------|
| Deleted March 11 bulk contamination | 2,591,933 rows deleted from fec_donations (Biden, Harris, Hillary, Bernie, Beasley, Cooper, etc.) |
| FEC reload | Cursor reloaded 14 clean files → 779,182 rows, 13 source files, locked and complete |
| D-flag cleanup | 935,162 D-flag rows deleted from contribution_map |
| Spine deactivation | 53,636 D-only persons deactivated (is_active=false) |
| Crossover aggregate recompute | 11,268 persons with D+R donations had D totals removed |
| TODO-1 NC_BOE party_flag | 108,943 NC_BOE contribution_map rows stamped party_flag='R' |
| TODO-2 UNKNOWN party_flag | 163,947 UNKNOWN rows resolved (WinRed→R, ncgop_god→R, remainder→OTHER) |
| TODO-3 candidate_id fill | 102,809 candidate_ids filled via CCM JOIN |
| Aggregate anomaly fix | 19,309 of 19,314 persons where total_R > total_contributed — recomputed |
| SESSION_START_READ_ME_FIRST | Fully updated, committed to GitHub |
| .cursorrules | Database section added — fires automatically when Cursor opens project |
| PERPLEXITY_SESSION_STARTER.md | One-page paste prompt for new Perplexity sessions |
| CURSOR_FEC_RELOAD_BRIEF.md | Cursor briefing with banned files, sacred tables, verification query |

### ⚠️ What Looks Done But Isn't

| Item | Reality |
|------|---------|
| FEC donors "in the database" | 779,182 rows in fec_donations but **person_id = 0 on all of them**. Completely unlinked to THE PEARL. |
| candidate_id fill | Filled 102,809 via CCM JOIN. But 2.2M still NULL because CCM bridge table is 61% empty. |
| Aggregate fix | 5 edge cases still have total_R > total_contributed |
| Dedup | RNCID dedup: 16 groups (15 real + 1 blank). Need human review. |

---

## DATABASE STATE — END OF SESSION (April 6, 2026 ~10 PM EDT)

### Core Tables
| Table | Rows | Status |
|-------|------|--------|
| `core.person_spine` active | 74,407 | ✅ Zero D-flag, zero dup NCIDs |
| `core.person_spine` inactive | 125,976 | ✅ |
| `core.contribution_map` | 2,960,201 | ✅ Zero party_flag='D' |
| `public.fec_donations` | 779,182 | ✅ 14 clean files — ⚠️ person_id=NULL on all |
| `public.nc_boe_donations_raw` | 338,223 | ✅ SACRED — installed, synced |
| `norm.nc_boe_donations` | 581,741 | ✅ 100% person_id linked |
| `norm.fec_individual` | 2,597,125 | ✅ 99.9997% person_id linked |
| `public.nc_datatrust` | 7,661,978 | ✅ SACRED |
| `archive.democratic_candidate_donor_records` | 906,609 | ✅ |

### contribution_map party_flag Distribution
| party_flag | Rows | Amount |
|------------|------|--------|
| R | 2,842,933 | $432.0M |
| OTHER | 116,157 | $20.2M |
| PAC | 1,111 | $889k |
| D | **0** | **$0** ✅ |

### fec_donations — 14 Approved Source Files (LOCKED)
| File | Rows |
|------|------|
| 2022-2026-Trump-nc-individ-only.csv | 377,778 |
| 2019-2020-Trump-NC-GOP-FEC.csv | 273,616 |
| 2015-2018-TRUMP-INDIDUALS.csv | 42,785 |
| tillis-burr-budd-2015-2026.csv | 30,845 |
| 2015-2026-us-house-fec-batch-one.csv | 20,450 |
| 2015-2026-us-house-batch2.csv | 12,186 |
| WHATLEY-MCCRORY-2015-2026-US-SENATE.csv | 7,602 |
| 2015-2026-us-house-batch-3.csv | 5,412 |
| group-1-pres-2015-2026.csv | 3,960 |
| batch-4-us-house.csv | 2,442 |
| group-2-2015-2026-president.csv | 1,594 |
| batch--5-house.csv | 408 |
| villaverde.csv | 104 |
| **TOTAL** | **779,182** |

Any `source_file` containing `2026-03-11` = contamination. Delete immediately.

---

## THE CRITICAL GAP — WHAT MUST BE DONE NEXT

### Gap 1 — FEC person_id Assignment (THE MOST CRITICAL)
**779,182 FEC rows have zero person_id.** They are sitting in `public.fec_donations` completely disconnected from `core.person_spine`. Until person_id is assigned, these donors are invisible to THE PEARL.

The correct process is `pipeline/identity_resolution.py` phases D, E, F:
- **Phase D** — Match FEC donors to existing spine rows (Pass 3: exact name+zip, Pass 5: initial+zip+employer)
- **Phase E** — Create new spine rows for FEC donors not matched to any NCBOE donor
- **Phase F** — Link remaining FEC rows to spine after Phase E

**BUT** — this must run AFTER the 7-pass DataTrust rollup (Gap 2 below), because the spine must be fully deduped before FEC donors are matched to it.

### Gap 2 — 7-Pass DataTrust Donor Rollup (RUN BEFORE FEC MATCHING)
Top 30% of donors appear under multiple name variants. Ed Broyhill = 8 name variants at 525 N Hawthorne 27104. All 8 must resolve to ONE person_id before FEC matching runs.

**The 7-pass rollup spec:** `sessions/2026-03-31_DONOR_ROLLUP_IDENTITY_SPEC.md`
**The Cursor execution brief:** `sessions/2026-03-31_DONOR_ROLLUP_CURSOR_BRIEF.md`
**The pipeline script:** `pipeline/identity_resolution.py`

**Pass sequence (DataTrust is the primary anchor — NOT just name+zip):**
1. voter_ncid exact bridge — 100% confidence, auto-merge
2. Street number + zip5 + last prefix — DataTrust registrationaddr1 — 97%
3. Employer + SIC + last prefix — DataTrust employer — 94%
4. Federal candidate cross-reference — FEC + NCBOE = two govt sources — 98%
5. Committee loyalty fingerprint — same 3+ committees across cycles — 96%
6. Canonical first name + last + zip — nickname normalization — 90%
7. Last + first + zip — standard match — 85%

**Canary before any merge:**
```sql
SELECT person_id, norm_first, norm_last, zip5, voter_ncid,
       total_contributed, contribution_count, is_active
FROM core.person_spine
WHERE norm_last = 'BROYHILL'
  AND zip5 IN ('27104','27012')
  AND is_active = true
ORDER BY total_contributed DESC;
```
All 8 variants must resolve to ONE person_id. If any variant maps differently — STOP.

**Current staging state:**
- `staging.donor_merge_candidates`: 0 rows (empty — rollup not run on clean data)
- `public.donor_merge_audit`: 0 rows
- `public.person_name_aliases`: 32 rows (Ed Broyhill aliases seeded)

### Gap 3 — FEC Candidate/Committee Matching Pipeline (DOES NOT EXIST)
The 4 NCBOE scripts handle NCBOE→committee→candidate linkage only:
- `2026-04-01_partisan_flag_fix.sql` — NCBOE only
- `2026-03-31_committee_candidate_fuzzy_match.sql` — NCBOE only
- `2026-04-01_committee_name_clean_patch.sql` — NCBOE only
- `2026-03-31_donor_candidate_matching.sql` — NCBOE only

**No equivalent FEC pipeline exists.** FEC donations link to candidates via `core.candidate_committee_map` but that table is 61% empty (2,229 of 5,761 have candidate_id). A FEC committee→candidate matching script needs to be built.

### Gap 4 — member_id / golden_record_id on nc_boe_donations_raw
`public.nc_boe_donations_raw` has `member_id` (338,223/338,223 populated) and `golden_record_id`. These are the donor identity links on the BOE side. Their role in the rollup pipeline is not fully documented here — read `sessions/2026-03-31_SPINE_COMPLETION_OPS_BRIEF.md` for the full downstream dependency map.

---

## THE CORRECT EXECUTION ORDER (Next Sessions)

**Do NOT skip steps. Do NOT run FEC matching before the rollup.**

| Order | Step | Script/Process | Auth needed |
|-------|------|---------------|-------------|
| 1 | Run 7-pass DataTrust rollup — NCBOE donors only | `pipeline/identity_resolution.py` phases A-G2 | Ed authorizes each merge pass after canary |
| 2 | Ed reviews `staging.donor_merge_candidates` | — | Ed reviews, authorizes merge execution |
| 3 | Execute approved merges via `MERGE_EXECUTOR_V1.sql` | — | "I authorize this action" |
| 4 | Run FEC identity matching phases D-F | `pipeline/identity_resolution.py` phases D, E, F | Ed authorizes |
| 5 | Build FEC candidate/committee matching pipeline | New script needed | Ed authorizes design first |
| 6 | Rebuild `core.contribution_map` from matched FEC | `sessions/2026-04-01_rollup_to_core.sql` | Ed authorizes |
| 7 | Recompute spine aggregates | `database/migrations/078_recalculate_spine_aggregates.sql` | Auto after step 6 |
| 8 | Build `donor_political_footprint` | New view/table | After steps 1-7 complete |
| 9 | Define top 30% threshold | SQL after footprint built | — |
| 10 | Activate clout scoring | E01 Triple Grading | After rollup complete |

---

## THE 8-STAGE MASTER DEPLOYMENT PLAN
**Already written April 2, 2026. Read it before proposing any next steps.**
`sessions/2026-04-02_MASTER_DEPLOYMENT_INSTRUCTIONS.md`

Stages 1-7 cover schema additions, enrichment, employer scan, record quality,
preferred name, honorary titles, and dedup passes — ALL for the spine.
Stage 8 covers NCBOE candidate/committee matching (the 4 scripts above).

**None of this has been run yet on the current clean data.**

---

## WHAT THE DONOR_POLITICAL_FOOTPRINT MUST CONTAIN
After rollup completes, every merged donor gets ONE row with:
- total_transactions, total_all_giving, committees_funded
- party_giving (tier 1/2), candidate_giving (tier 4), pac_giving (tier 5/6/7)
- ncboe_giving, fec_giving, winred_giving
- r_pct (partisan lean), last_gift_date, first_gift_date, active_cycles

This is the output that makes scoring, ranking, and fundraiser targeting accurate.

---

## NCBOE CANDIDATE/COMMITTEE LINKAGE — CURRENT STATE
`staging.boe_donation_candidate_map` — 338,213 rows — built and exists
`staging.committee_candidate_bridge` — built via fuzzy match script
`staging.committee_registry_clean_names` — built via name clean patch

These staging tables were built from prior sessions. Verify they still exist before
running any NCBOE-related work. The 4 scripts are idempotent (DROP IF EXISTS before CREATE).

---

## TWILIO / MMS STATUS
- Brand: APPROVED
- Campaign: FAILED (4 errors — no public privacy policy, no T&C, CTA not verifiable)
- broyhillgop.com redirects to /login.php — no public pages
- Fix needed: Add broyhillgop.com/privacy-policy and broyhillgop.com/terms as public pages
- Then resubmit campaign via Twilio API
- Timeline: 10-15 business days after resubmission

---

## INFRASTRUCTURE
| Resource | Value |
|----------|-------|
| Supabase project | isbgjpnbocdkeslofota (us-east-1) |
| Pooler | db.isbgjpnbocdkeslofota.supabase.co port 6543 |
| GitHub repo | broyhill/BroyhillGOP |
| Hetzner Server | 5.9.99.109 (relay port 8080) |
| DataTrust contact | Danny Gustafson dgustafson@gop.com |
| DataTrust token expires | April 10, 2026 — RENEW NOW |
| FEC API key | ROTATE — compromised, posted in chat |
| DB password | ROTATE — compromised, posted in chat |
| Twilio Account SID | See Twilio console — BroyhillGOP account |
| Twilio Key SID | See Twilio console — BroyhillGOP-Twillio key |

---

## ED'S RULES (Non-Negotiable)
1. NC donors only
2. Individual donors only — no corps, PACs, LLCs, associations
3. Republican candidates only
4. Democrat/UNA crossover donors who give to Republicans — KEEP
5. D-only donors — REMOVE (done April 6)
6. "Ed" is NOT mapped to "Edward" — ever
7. No committee-to-committee donations
8. Do not drop schema columns without knowing why
9. TWO PHASE PROTOCOL — DRY RUN then "I authorize this action"
10. Do not guess the pipeline — read the spec first

---

*Written by Perplexity-Claude | April 6, 2026 ~10 PM EDT*
*Ed Broyhill pushed back 6+ times tonight to prevent wrong actions.*
*Every pushback was correct. The lesson: read everything before recommending anything.*

---

## CRITICAL FINDING — Added 10:06 PM EDT

### ~90,545 NCBOE Donors Are Staged But NOT in THE PEARL

**This was discovered at end of session. Not a deletion — a rollup gap.**

| Source | Status |
|--------|--------|
| `norm.nc_boe_donations` | 581,741 rows — 100% linked to person_id ✅ |
| `core.contribution_map` NC_BOE rows | 108,943 rows — only 19,981 distinct persons |
| Gap | ~90,545 NCBOE donors staged but never rolled up into contribution_map |

The identity matching IS done — `norm.nc_boe_donations` has person_id on every row.
The INSERT into `core.contribution_map` was never completed.

**Fix:** `sessions/2026-04-01_rollup_to_core.sql` — Stage 8 of master deployment plan.
This is the LOWEST RISK, HIGHEST VALUE next move. No new matching needed.

### Revised True Donor Universe Estimate
- NCBOE rolled up: 18,752 persons
- NCBOE staged (ready to roll up): ~90,545 persons  
- FEC (needs identity matching first): ~150,000-200,000 new persons estimated
- **TRUE ADDRESSABLE UNIVERSE: likely 150,000-200,000+ unique NC Republican donors**

Current spine of 74,407 active persons is a fraction of what it will be when complete.

### Revised Priority Order for Next Session
1. NCBOE rollup → contribution_map (`2026-04-01_rollup_to_core.sql`) — already identity-resolved, just needs INSERT
2. 7-pass DataTrust rollup — dedup spine before FEC matching
3. FEC identity matching — phases D, E, F of identity_resolution.py
4. FEC candidate/committee pipeline — new script needed
