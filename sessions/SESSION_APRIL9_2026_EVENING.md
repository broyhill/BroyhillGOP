# SESSION — April 9, 2026 Evening
**BroyhillGOP-Claude | Recorded: April 9, 2026 ~6:10 PM EDT**
**Authority: Ed Broyhill | NC National Committeeman**

---

## INCIDENT #13 — nc_boe_donations_raw CONTAMINATION (DO NOT REPEAT)

For the 13th time, an agent loaded the 18 GOLD NCBOE files by APPENDING rather than running TRUNCATE-first. The table now contains ~2,269,053 rows — a contaminated hybrid of enriched sacred rows + raw unenriched new rows with zero voter_ncid, no RNCID, and no DataTrust linkage.

**Root cause:** Agent did not read `SESSION_START_READ_ME_FIRST.md` before acting. Two-Phase Protocol was not followed. No dry run was presented to Ed. No "I authorize this action" was obtained.

**Pattern from session history:**
- March 8, 2026: same failure — nc_boe_donations_raw had 1,148,939 rows from prior append
- April 7-8, 2026: 221,437 rows loaded (partial GOLD load in progress)
- April 9 evening: ~1,930,000 more rows appended = total ~2,269,053

This is a **procedural failure, not a technical one.** The fix is reading the session file first, every time, without exception.

---

## WHAT IS SAFE RIGHT NOW

| Table | Live Rows | Status |
|-------|-----------|--------|
| `public.nc_datatrust` | 7,661,978 | ✅ SACRED — untouched |
| `public.nc_voters` | 9,079,672 | ✅ SACRED — untouched |
| `public.rnc_voter_staging` | 7,708,268 | ✅ SACRED — untouched |
| `staging.nc_voters_fresh` | 7,707,910 | ✅ SACRED — untouched |
| `public.person_master` | 7,728,689 | ✅ untouched |
| `public.fec_donations` | 783,887 | ✅ LOCKED |
| `public.contacts` | 226,821 | ✅ untouched |
| `core.person_spine` | ~200,383 | ✅ THE PEARL — untouched |
| `core.contribution_map` | 2,953,533 | ✅ untouched |
| `public.nc_boe_donations_raw` | **~2,269,053** | 🔴 CONTAMINATED |

---

## RECOVERY PLAN

**Step 1 — Ed says: "I authorize this action"**

**Step 2 — TRUNCATE:**
```sql
SET statement_timeout = 0;
TRUNCATE public.nc_boe_donations_raw;
SELECT COUNT(*) FROM public.nc_boe_donations_raw; -- must return 0
```

**Step 3 — Reload 338,223 sacred rows from backup:**
```sql
INSERT INTO public.nc_boe_donations_raw
SELECT * FROM audit.nc_boe_donations_raw_pre_reload_20260330;
SELECT COUNT(*) FROM public.nc_boe_donations_raw; -- must return 338,223
```

**Step 4 — Verify exact count before proceeding:**
If count ≠ 338,223 exactly — STOP. Report to Ed.

---

## EARLIER SESSIONS TODAY (April 9, 2026)

### Morning Session (12:15 AM) — Database Reset Decision
- All prior FEC and NCBOE files confirmed contaminated (Democratic candidates, out-of-state donors, throttled bulk downloads)
- Supabase database restored to April 9, 7:00 AM snapshot
- New file sourcing rules established: break downloads by county/city/candidate, filter at source
- SESSION_START_READ_ME_FIRST.md updated at 12:15 AM

### Afternoon — Docs Folder Inventory
- Full docs/ folder catalog shared with Ed (75 files across 8 categories)
- GitHub confirmed as source of truth; session files confirmed as the authoritative state layer
- Voter file schema confirmed: nc_voters has 67 columns including all district fields for 2,500-candidate GOTV use case

### Evening (6:10 PM) — Incident #13 Discovered
- Live Supabase count shows 2,269,053 rows in nc_boe_donations_raw
- Incident documented, SESSION_START_READ_ME_FIRST.md updated with live counts and recovery protocol
- This session file created

---

## VOTER FILE STATUS (SACRED TABLES ARE CLEAN)

The earlier concern about the voter file is resolved: the sacred tables are intact and correctly structured.

- `public.nc_voters` — 9,079,672 rows ✅ — 67 columns, full NCSBE schema including all district fields
- `staging.nc_voters_fresh` — 7,707,910 rows ✅ — DataTrust-enriched voter file
- `public.nc_datatrust` — 7,661,978 rows ✅ — RNC DataTrust enrichment

All district columns needed for 2,500-candidate GOTV platform are present in nc_voters:
- `cong_dist_abbrv`, `nc_senate_abbrv`, `nc_house_abbrv`
- `county_commis_abbrv`, `school_dist_abbrv`, `municipality_abbrv`
- `precinct_abbrv`, `fire_dist_abbrv`, `rescue_dist_abbrv`, etc.

---

## INFRASTRUCTURE NOTES

- **DataTrust token expires April 10, 2026** — URGENT: contact Zack Imel (RNC Digital Director) today
- **DB password compromised** — rotate at Supabase dashboard
- **FEC API key compromised** — rotate at api.data.gov
- **GitHub is now confirmed as live source of truth** — Perplexity committed this update directly

---

## NEXT STEPS (Blocked Until Ed Acts)

1. **Ed authorizes nc_boe_donations_raw recovery** — say "I authorize this action"
2. Perplexity or Cursor runs TRUNCATE → reload → verify 338,223
3. Contact Zack Imel re: DataTrust token renewal today
4. Rotate DB password and FEC API key
5. Resume GOLD 18-file load — with TRUNCATE-first protocol enforced for every batch

---

*Recorded by Perplexity | April 9, 2026 6:10 PM EDT*
*Ed Broyhill — NC National Committeeman | ed.broyhill@gmail.com*
