# PERPLEXITY SESSION STARTER
## Paste this at the start of every new Perplexity session for BroyhillGOP database work

---

You are working on the BroyhillGOP-Claude database project. Before doing anything, read the following briefing completely and confirm you have read it.

## Project
- Supabase project: isbgjpnbocdkeslofota (us-east-1)
- Pooler: db.isbgjpnbocdkeslofota.supabase.co port 6543 sslmode=require
- Always run: SET statement_timeout = 0;
- GitHub: broyhill/BroyhillGOP

## The Pearl
core.person_spine = THE PEARL. 74,407 active persons. Master unified identity table.
Never touch without "I authorize this action" from Ed.

## Sacred Tables — Never Touch
- public.nc_boe_donations_raw — 338,223 rows — installed, synced, do not touch
- norm.nc_boe_donations — 581,741 rows — normalized, do not touch
- public.nc_datatrust — 7,661,978 rows — primary identity anchor, SACRED
- public.nc_voters — SACRED
- public.rnc_voter_staging — SACRED
- public.person_source_links — SACRED

## Rules
- TWO PHASE PROTOCOL: DRY RUN first, EXECUTION only after "I authorize this action"
- NC donors only, individual donors only, Republican candidates only
- Democrat crossover donors ARE kept (DEM/UNA who donate to Republicans)
- D-only donors are removed (deactivated April 6, 2026 — complete)
- "Ed" is NOT mapped to "Edward" — ever
- Do not drop schema columns without knowing why they exist

## Current State (April 6, 2026)
- core.person_spine active: 74,407 | contribution_map: 2,960,201 | Zero D-flag rows
- fec_donations: 779,182 rows — 14 approved files only — LOCKED AND COMPLETE
- nc_boe_donations_raw: 338,223 rows — SACRED
- Banned: any fec_donations source_file containing "2026-03-11" — delete on sight

## Most Important Pending Task
The 7-pass donor rollup per sessions/2026-03-31_DONOR_ROLLUP_IDENTITY_SPEC.md
DataTrust registrationaddr1 is the Pass 2 anchor — NOT just name+zip
Ed Broyhill (8 name variants, 525 N Hawthorne, 27104) = the canary
All 8 variants must resolve to ONE person_id before any merge runs
Do NOT use 083_match_fec_to_spine.sql as the rollup — that misses the DataTrust anchors

## Full Briefing
Read sessions/SESSION_START_READ_ME_FIRST.md in the GitHub repo for the complete picture.
State in your first reply that you have read this starter prompt.

---
*Ed Broyhill | NC National Committeeman | ed.broyhill@gmail.com*
