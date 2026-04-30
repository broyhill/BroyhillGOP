-- =============================================================================
-- BroyhillGOP — Party Committee Donor File Ingestion Playbook (V4)
-- Built:   2026-04-26
-- Author:  Claude (Cowork mode), at Ed Broyhill's direction
-- Scope:   Detailed status query + remediation SQL to conclude V4 ingestion of
--          staging.ncboe_party_committee_donations on Hetzner prod-db.
--
-- READ FIRST:
--   - SESSION-STATE.md (last updated 2026-04-20 by Nexus)
--   - REVISED_PLAN_APR15.md (master 8-phase plan)
--   - sessions/2026-04-18/phase2_committee_replication/MATCH_RATE_DIAGNOSIS.md
--   - database/sql/committee_party_donor_golden_build.sql (last applied)
--
-- AUTHORIZATION GATE:
--   Anything destructive on raw.ncboe_donations or staging.ncboe_party_committee_donations
--   requires Ed to type the EXACT phrase: "I AUTHORIZE THIS ACTION"
--   Yes / ok / go ahead are NOT authorization.
--
-- CONNECTION (rotated since the V7 skill was written — confirm before running):
--   Host: 37.27.169.232 | Port: 5432 | DB: postgres | User: postgres
--   Password: <rotated — pull from sessions/2026-04-18/HETZNER_NEW_CREDS.redacted.txt>
--   Tailscale path: ssh root@hetzner-1 (100.108.229.41) — preferred
-- =============================================================================


-- =============================================================================
-- SECTION 0 — MANDATORY PRE-FLIGHT (run before ANY remediation)
-- =============================================================================

-- 0.1 Read live session_state body. Per Ed's 2026-04-26 update, the latest row
-- is id=19 (updated_by Nexus-2026-04-25, 2902 chars). The body is NOT in any
-- committed file in the repo — it lives only in this row. Read it first.
SELECT id, updated_at, updated_by, length(state_md) AS chars, state_md
FROM   public.session_state
ORDER  BY id DESC
LIMIT  1;

-- 0.2 Sacred-spine integrity. The post-tumor-cleanup spine is 321,348 rows /
-- 98,303 distinct clusters. Anything else = STOP and tell Ed before proceeding.
SELECT
  (SELECT COUNT(*)              FROM raw.ncboe_donations)                              AS spine_rows,        -- expect 321,348
  (SELECT COUNT(DISTINCT cluster_id) FROM raw.ncboe_donations)                         AS spine_clusters,    -- expect  98,303
  (SELECT COUNT(*)              FROM raw.ncboe_donations WHERE rnc_regid IS NOT NULL)  AS voter_matched,     -- expect ~80,605 in donor_profile (82% of clusters)
  (SELECT COUNT(*)              FROM core.donor_profile)                               AS donor_profile_rows,-- expect 98,303 (Stage 1 done 2026-04-18)
  (SELECT COUNT(*)              FROM core.datatrust_voter_nc)                          AS datatrust_rows,    -- expect 7,727,637
  (SELECT COUNT(*)              FROM core.acxiom_ap_models)                            AS acxiom_rows;       -- expect 7,655,593

-- 0.3 Ed canary. The 2026-04-15 transaction-dedup fix collapsed cluster 372171
-- from 627 inflated txns / $1.32M down to 147 real txns / $332,631.30.
-- If you see 627 / $1.32M anywhere → you are querying an inflated/dropped table. STOP.
SELECT cluster_id,
       COUNT(*)                  AS txns,            -- expect 147
       SUM(norm_amount)          AS total,           -- expect 332631.30
       MAX(cell_phone)           AS cell,            -- expect 3369721000
       MAX(personal_email)       AS p_email,         -- expect ed@broyhill.net   (NEVER jsneeden@msn.com — Apollo bad data)
       MAX(home_phone)           AS home,
       MAX(business_email)       AS b_email,
       BOOL_OR(trump_rally_donor) AS rally           -- expect TRUE
FROM   raw.ncboe_donations
WHERE  cluster_id = 372171
GROUP  BY cluster_id;


-- =============================================================================
-- SECTION 1 — COMPLETE DATABASE STATUS QUERY
-- One screen-full of numbers covering every table that touches Party Committee
-- Donor ingestion. Run this any time you want a single-pass health check.
-- =============================================================================

WITH spine AS (
  SELECT 'raw.ncboe_donations'                AS object,
         COUNT(*)                             AS rows,
         COUNT(DISTINCT cluster_id)           AS clusters,
         SUM(norm_amount)                     AS dollars,
         MIN(date_occured)::text              AS earliest,
         MAX(date_occured)::text              AS latest
  FROM   raw.ncboe_donations
),
party_stage AS (
  SELECT 'staging.ncboe_party_committee_donations',
         COUNT(*),
         COUNT(DISTINCT cluster_id)           FILTER (WHERE cluster_id IS NOT NULL),
         SUM(norm_amount),
         MIN(norm_date)::text,
         MAX(norm_date)::text
  FROM   staging.ncboe_party_committee_donations
),
party_unresolved AS (
  SELECT 'party_stage.committee_name_resolved IS NULL',
         COUNT(*) FILTER (WHERE committee_name_resolved IS NULL),
         NULL::bigint, NULL::numeric, NULL::text, NULL::text
  FROM   staging.ncboe_party_committee_donations
),
party_unmatched AS (
  SELECT 'party_stage.cluster_id IS NULL (unlinked donors)',
         COUNT(*) FILTER (WHERE cluster_id IS NULL),
         NULL::bigint, NULL::numeric, NULL::text, NULL::text
  FROM   staging.ncboe_party_committee_donations
),
cluster_v2_nulls AS (
  SELECT 'raw.ncboe_donations.cluster_id_v2 IS NULL',
         COUNT(*) FILTER (WHERE cluster_id_v2 IS NULL),
         NULL::bigint, NULL::numeric, NULL::text, NULL::text
  FROM   raw.ncboe_donations
),
suffix_conflicts AS (
  SELECT 'cluster suffix conflicts (JR/SR/II/III/IV)',
         COUNT(*) FILTER (WHERE n_distinct_suffix > 1),
         NULL::bigint, NULL::numeric, NULL::text, NULL::text
  FROM (
    SELECT cluster_id, COUNT(DISTINCT norm_name_suffix) AS n_distinct_suffix
    FROM   raw.ncboe_donations
    WHERE  norm_name_suffix IS NOT NULL
    GROUP  BY cluster_id
  ) s
),
cmm AS (
  SELECT 'committee.boe_donation_candidate_map',
         COUNT(*),
         COUNT(*) FILTER (WHERE candidate_name IS NOT NULL),     -- coverage of candidate match
         NULL::numeric,
         NULL::text, NULL::text
  FROM   committee.boe_donation_candidate_map
),
golden AS (
  SELECT 'committee.party_donor_golden',
         COUNT(*),
         COUNT(DISTINCT cluster_id),
         SUM(total_amount),
         NULL::text, NULL::text
  FROM   committee.party_donor_golden
)
SELECT * FROM spine
UNION ALL SELECT * FROM party_stage
UNION ALL SELECT * FROM party_unresolved
UNION ALL SELECT * FROM party_unmatched
UNION ALL SELECT * FROM cluster_v2_nulls
UNION ALL SELECT * FROM suffix_conflicts
UNION ALL SELECT * FROM cmm
UNION ALL SELECT * FROM golden;

/*
EXPECTED PRINT (per 2026-04-26 V4 preflight + April-20 SESSION-STATE):

  raw.ncboe_donations                              321,348 rows / 98,303 clusters
  staging.ncboe_party_committee_donations          293,396 rows
  party_stage.committee_name_resolved IS NULL      293,396  ← 100% NULL — name-resolution pass NOT YET RUN  ★
  party_stage.cluster_id IS NULL                   ~13,158   (5,705 no addr, 3,981 not in spine, 167 OOS, rest ambiguous)
  raw.ncboe_donations.cluster_id_v2 IS NULL        8,778    ← V2 cluster pass incomplete                    ★
  cluster suffix conflicts                         17       ← JR/SR/II/III/IV conflicts inside one cluster  ★
  committee.boe_donation_candidate_map             338,213 / 249,957 with candidate_name (73.91%)           ★
                                                              88,256 'U' rows wrongly nulled — see Section 2
  committee.party_donor_golden                     ~98,303 clusters / build per committee_party_donor_golden_build.sql
*/


-- =============================================================================
-- SECTION 2 — DETAILED PROBLEMS WITH THE PARTY COMMITTEE DONOR FILE
-- Eight distinct issues, each with diagnosis SQL.
-- =============================================================================

-- 2.1 Problem A — committee_name_resolved is 100% NULL (NAME PASS NEVER RUN)
-- The name-resolution pass that converts raw committee_name → canonical
-- committee.registry.committee_name has not been executed for V4.
-- Without this, every downstream view that joins on resolved name returns 0 rows.
SELECT 'A. committee_name_resolved coverage' AS problem,
       COUNT(*)                                                                     AS total_rows,
       COUNT(*) FILTER (WHERE committee_name_resolved IS NOT NULL)                  AS resolved,
       ROUND(100.0 * COUNT(*) FILTER (WHERE committee_name_resolved IS NOT NULL) /
             NULLIF(COUNT(*), 0), 2)                                                AS pct_resolved
FROM   staging.ncboe_party_committee_donations;
-- Expected: 0% resolved → ~100% gap. Fix is in Section 3, Stage S1.


-- 2.2 Problem B — 88,256 downballot rows wrongly classified partisan_flag='U'
-- (Source: sessions/2026-04-18/phase2_committee_replication/MATCH_RATE_DIAGNOSIS.md)
-- Cursor's 2026-04-01 audit reported 99.67% candidate match. By 2026-04-18 the
-- partisan classifier had been re-run and 88,256 downballot Republican rows
-- (sheriff, DA, judicial, county) were flipped R→U and had candidate_name nulled.
SELECT 'B. partisan_flag breakdown' AS problem,
       partisan_flag,
       COUNT(*)                                                                     AS rows,
       COUNT(*) FILTER (WHERE candidate_name IS NOT NULL)                           AS named,
       ROUND(100.0 * COUNT(*) FILTER (WHERE candidate_name IS NOT NULL) /
             NULLIF(COUNT(*),0), 2)                                                 AS pct_named
FROM   committee.boe_donation_candidate_map
GROUP  BY partisan_flag
ORDER  BY rows DESC;
-- Expected: R = 249,957 / 100% named.   U = 88,256 / 0% named.   Fix in Section 3 Stage S2.


-- 2.3 Problem C — 8,778 cluster_id_v2 NULLs (Union-Find V2 pass incomplete)
SELECT 'C. cluster_id_v2 NULLs' AS problem,
       COUNT(*) FILTER (WHERE cluster_id_v2 IS NULL)        AS null_v2_rows,
       COUNT(DISTINCT cluster_id) FILTER (WHERE cluster_id_v2 IS NULL) AS distinct_legacy_clusters_affected
FROM   raw.ncboe_donations;
-- Expected: 8,778 NULL rows. Fix = re-run Stage 1G of ncboe_dedup_v2.py for the
-- gap rows ONLY (not full re-run — that would clobber 321,348 settled clusters).


-- 2.4 Problem D — 17 suffix conflicts inside single clusters
-- Same cluster_id contains mixed JR/SR/II/III/IV — likely cross-generation merge
-- (e.g., James T. Broyhill SR. and Edgar Broyhill II ending up in one cluster).
SELECT 'D. suffix conflict clusters' AS problem,
       cluster_id,
       array_agg(DISTINCT norm_name_suffix) AS suffixes,
       array_agg(DISTINCT norm_name_first ORDER BY norm_name_first) AS firsts,
       COUNT(*) AS rows
FROM   raw.ncboe_donations
WHERE  norm_name_suffix IS NOT NULL
GROUP  BY cluster_id
HAVING COUNT(DISTINCT norm_name_suffix) > 1
ORDER  BY rows DESC
LIMIT  20;
-- Expected: 17 clusters. Fix = manual splitter (Stage S4) — small enough to eyeball.


-- 2.5 Problem E — 13,158 unlinked individual party donors (cluster_id IS NULL
-- in staging.ncboe_party_committee_donations). Root-cause breakdown per
-- REVISED_PLAN_APR15.md Phase 2:
SELECT 'E. unlinked donor breakdown' AS problem,
       CASE
         WHEN street_line_1 IS NULL AND norm_zip5 IS NULL AND city IS NULL
                                                         THEN '5705_no_addr'
         WHEN state IS NOT NULL AND state <> 'NC'         THEN '167_out_of_state'
         WHEN cluster_id IS NULL                          THEN '3981_name_not_in_spine'
         ELSE 'remaining_ambiguous'
       END                                                AS bucket,
       COUNT(*)                                           AS rows
FROM   staging.ncboe_party_committee_donations
WHERE  cluster_id IS NULL
GROUP  BY 1
ORDER  BY rows DESC;
-- Expected (per April-15 plan): 5,705 / 167 / 3,981 / ~3,305 ambiguous = 13,158 total.


-- 2.6 Problem F — Committee Ingestion V4 preflight (2026-04-26) is NOT in git
-- The file `docs/runbooks/committee_ingestion_v4_preflight_20260426_0059.md`
-- is referenced in the latest session but is not committed to the repo as of
-- commit e237d67 (2026-04-25 22:19 EDT). Either:
--   (i)   Lives only on Hetzner under /opt/broyhillgop/, or
--   (ii)  Lives in an unpushed local branch on Ed's Mac, or
--   (iii) Was generated in-session and never written to disk.
-- Action: Ed should push it / paste it / copy from server.


-- 2.7 Problem G — public.session_state on Hetzner only updated through id=19
-- (Nexus-2026-04-25, 2,902 chars). Several of the runs since then have not
-- written a new row, so the in-database memory is one cycle behind reality.
-- Fix is in Section 3 Stage S7.


-- 2.8 Problem H — Hetzner network lock from 2026-04-17 abuse incident may
-- still be in effect at the datacenter edge, blocking external Postgres on
-- 37.27.169.232:5432 above the UFW. Tailscale (100.108.229.41) is the only
-- reliable path until Ed completes the Hetzner abuse-reply.


-- =============================================================================
-- SECTION 3 — REVISED INGESTION PLAN TO CONCLUDE THE PARTY COMMITTEE DONOR FILE
-- 8 stages. Each must complete & be Ed-verified before the next. Each is
-- non-destructive on raw.ncboe_donations except where flagged ⚠️ AUTH REQUIRED.
-- =============================================================================

-- ─── STAGE S0 — Pre-flight (every run, no exceptions) ────────────────────────
-- See Section 0 above. Run, confirm row counts + Ed canary, report to Ed,
-- WAIT for Ed to say "go" before any further work.


-- ─── STAGE S1 — committee_name_resolved backfill (NAME PASS) ─────────────────
-- Resolves staging.ncboe_party_committee_donations.committee_name → canonical
-- name from committee.registry. Currently 100% NULL.
BEGIN;
  UPDATE staging.ncboe_party_committee_donations p
     SET committee_name_resolved = r.committee_name
    FROM committee.registry r
   WHERE p.committee_sboe_id = r.sboe_id
     AND p.committee_name_resolved IS NULL
     AND r.committee_name IS NOT NULL;
  -- Report row count BEFORE COMMIT
  SELECT COUNT(*) AS resolved_now
    FROM staging.ncboe_party_committee_donations
   WHERE committee_name_resolved IS NOT NULL;
COMMIT;
-- Expected: ~280,000+ rows resolve, leaving a small residue with no sboe_id match.


-- ─── STAGE S2 — Backfill 88,256 'U' downballot candidate_name + flip flag ────
-- (Per MATCH_RATE_DIAGNOSIS.md, the fix is two passes.)
BEGIN;
  -- 2a. Restore candidate_name from registry where it was nulled
  UPDATE committee.boe_donation_candidate_map m
     SET candidate_name = r.candidate_name
    FROM public.committee_registry r
   WHERE m.committee_sboe_id    = r.sboe_id
     AND m.candidate_name       IS NULL
     AND r.candidate_name       IS NOT NULL;
  -- 2b. Flip partisan_flag from 'U' → 'R' for downballot Republican races
  UPDATE committee.boe_donation_candidate_map m
     SET partisan_flag = 'R'
    FROM public.committee_registry r
   WHERE m.committee_sboe_id    = r.sboe_id
     AND m.partisan_flag        = 'U'
     AND r.candidate_party      ILIKE 'REP%';
  -- Verify recovery
  SELECT partisan_flag,
         COUNT(*)                                          AS rows,
         ROUND(100.0 * COUNT(*) FILTER (WHERE candidate_name IS NOT NULL)
               / NULLIF(COUNT(*),0), 2)                    AS pct_named
    FROM committee.boe_donation_candidate_map
   GROUP BY partisan_flag
   ORDER BY rows DESC;
COMMIT;
-- Expected post-fix: R ≥ 99% named, U ≈ 0 rows.


-- ─── STAGE S3 — Re-run cluster_id_v2 for 8,778 NULL rows (gap-only) ──────────
-- ⚠️ AUTH REQUIRED — this writes back to raw.ncboe_donations.
-- Procedure: run ncboe_dedup_v2.py with --where "cluster_id_v2 IS NULL" and
-- --no-clobber so settled rows are untouched. Verify after:
SELECT COUNT(*) FILTER (WHERE cluster_id_v2 IS NULL) AS still_null
FROM   raw.ncboe_donations;
-- Expected after: 0.


-- ─── STAGE S4 — Resolve 17 suffix-conflict clusters (manual splitter) ────────
-- ⚠️ AUTH REQUIRED — modifies cluster_id assignments on raw.ncboe_donations.
-- Process: pull the 17 clusters with Section 2.4 query, eyeball each, generate
-- new cluster_ids for the split-out generation, write a single migration:
--   sessions/2026-04-26/migrations/04_split_suffix_conflicts.sql
-- Containing one UPDATE per cluster.
-- Re-run Section 0.3 (Ed canary) after — must still show 147 / $332,631.30.


-- ─── STAGE S5 — Build/refresh committee.party_donor_golden ───────────────────
-- This is the published output for the Party Committee Donor file.
-- Source: database/sql/committee_party_donor_golden_build.sql (committed 3d68ba4).
-- Not destructive of raw — it DROPs/recreates committee.party_donor_golden and
-- committee.party_donor_committee_map only. Run as-is.
\i database/sql/committee_party_donor_golden_build.sql
SELECT * FROM pg_stat_user_tables
 WHERE schemaname='committee'
   AND relname IN ('party_donor_golden','party_donor_committee_map');


-- ─── STAGE S6 — Recover 13,158 unlinked donors (best effort, two passes) ─────
-- 6a. Cluster-by-employer rescue (REVISED_PLAN_APR15.md Phase 8):
--     Match unlinked party donor → spine where (last_name, employer_normalized) match.
INSERT INTO staging.ncboe_party_committee_donations_recovered (party_id, cluster_id, source)
SELECT p.id, s.cluster_id, 'employer_match'
FROM   staging.ncboe_party_committee_donations p
JOIN   raw.ncboe_donations s
       ON  upper(p.norm_name_last) = upper(s.norm_name_last)
       AND upper(coalesce(p.employer_normalized,'')) = upper(coalesce(s.employer_normalized,''))
       AND p.employer_normalized IS NOT NULL
WHERE  p.cluster_id IS NULL;

-- 6b. Geocode rescue via DataTrust 2,200-variable file (Acxiom lat/lon vs addr).
--     Defer until employer rescue is verified.


-- ─── STAGE S7 — Update public.session_state (id=20) ──────────────────────────
INSERT INTO public.session_state (updated_by, state_md)
VALUES ('Claude-2026-04-26', $STATE$
# BroyhillGOP — Session State (id=20)
**Last updated: 2026-04-26 (after V4 ingestion concluded)**

## Current Canary
| Field           | Value                  |
|-----------------|------------------------|
| Table           | raw.ncboe_donations    |
| Cluster         | 372171                 |
| Transactions    | 147                    |
| Total           | $332,631.30            |
| Email           | ed@broyhill.net        |

## V4 Party Committee Donor Ingestion — CONCLUDED
- Stage S1 committee_name_resolved coverage: <fill in pct>
- Stage S2 partisan_flag U→R fix: <rows updated>
- Stage S3 cluster_id_v2 backfill: <rows fixed>
- Stage S4 suffix-conflict splits: <clusters split>
- Stage S5 party_donor_golden: <rows>
- Stage S6 employer rescue: <rows recovered>

## Open
- Geocode rescue (Stage S6b)
- Stage 1b business-address bridge
- Dropbox nightly backup (rclone)
- Hetzner abuse-reply lock lift
$STATE$);


-- ─── STAGE S8 — Drop stale Supabase shadow tables (only after Hetzner parity) ─
-- ⚠️ AUTH REQUIRED — Supabase-side, not Hetzner.
-- DROP TABLE staging.boe_donation_candidate_map;
-- DROP TABLE public.nc_boe_donations_raw;
-- DROP TABLE secondary.nc_boe_party_committee_donations;
-- DROP TABLE public.committee_registry;


-- =============================================================================
-- SECTION 4 — VERIFICATION CANARY (run after EVERY stage)
-- =============================================================================
-- 4.1 Spine canary (must always pass)
SELECT cluster_id, COUNT(*) AS txns, SUM(norm_amount) AS total
FROM   raw.ncboe_donations WHERE cluster_id = 372171
GROUP  BY cluster_id;
-- Expected: 147 / 332631.30

-- 4.2 Party canary — Ed's combined party giving
SELECT 'ed_party_total' AS check,
       COUNT(*) AS txns, SUM(norm_amount) AS total
FROM   staging.ncboe_party_committee_donations
WHERE  cluster_id = 372171;
-- Expected: 40 / 155,945.45

-- 4.3 Combined canary
SELECT 488576.75 AS expected_combined,
       (SELECT SUM(norm_amount) FROM raw.ncboe_donations WHERE cluster_id=372171)
     + (SELECT SUM(norm_amount) FROM staging.ncboe_party_committee_donations WHERE cluster_id=372171)
                  AS actual_combined;
-- Must match: $488,576.75

-- 4.4 Apollo bad-data guard
SELECT 'jsneeden_check' AS check,
       COUNT(*) FILTER (WHERE personal_email = 'jsneeden@msn.com') AS apollo_bad_rows
FROM   raw.ncboe_donations WHERE cluster_id = 372171;
-- Expected: 0. If >0 → STOP, clear before any further work.


-- =============================================================================
-- END OF PLAYBOOK — built from on-disk repo files + Ed's 2026-04-26 V4 update.
-- The live state_md body for id=19 (2,902 chars) and the 2026-04-26 V4 preflight
-- are NOT in the GitHub repo as of commit e237d67. Confirm with Ed before run.
-- =============================================================================
