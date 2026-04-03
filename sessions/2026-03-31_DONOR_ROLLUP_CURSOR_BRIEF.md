# Donor Rollup — Cursor Execution Brief
## BroyhillGOP — March 31, 2026
## Authority: Ed Broyhill
## Agent: Cursor (direct psql, Mac)

---

## MANDATE

Roll up all name variants of the same donor to a single person_id.
The top 30% of donors give multiple times under multiple name variants.
Every pass must be staged first. No auto-merge without a canary verification.
Ed Broyhill ($1,016,573, 32 name variants) is the canary — if his rollup
is wrong, stop and report before touching anyone else.

---

## PRE-FLIGHT (run first, report results)

```sql
-- 1. Confirm clean NCBOE data
SELECT count(*), count(*) FILTER (WHERE transaction_type = 'Individual')
FROM public.nc_boe_donations_raw;
-- Expected: 338,223 total, 338,223 Individual

-- 2. Confirm person_spine baseline
SELECT count(*) AS active_spine, round(sum(total_contributed)) AS total_dollars
FROM core.person_spine WHERE is_active = true;
-- Record baseline before any merges

-- 3. Create alias tables
CREATE TABLE IF NOT EXISTS public.person_name_aliases (
  id               bigserial PRIMARY KEY,
  person_id        int NOT NULL,
  alias_name       text NOT NULL,
  alias_type       text NOT NULL CHECK (alias_type IN (
    'legal','goes_by','middle_as_first','initial','abbreviated',
    'nickname_quoted','paren_variant','typo','fec_format','fec_honorific',
    'mixed_case','proxy_filing'
  )),
  source_system    text,
  confidence       numeric(4,3) DEFAULT 1.000,
  notes            text,
  created_at       timestamptz DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_pna_person_alias
  ON public.person_name_aliases (person_id, alias_name);
CREATE INDEX IF NOT EXISTS idx_pna_alias_upper
  ON public.person_name_aliases (upper(alias_name));

CREATE TABLE IF NOT EXISTS public.employer_aliases (
  id               bigserial PRIMARY KEY,
  canonical_employer text NOT NULL,
  alias_employer   text NOT NULL,
  sic_code         text,
  naics_code       text,
  confidence       numeric(4,3) DEFAULT 1.000,
  notes            text,
  created_at       timestamptz DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_ea_canonical_alias
  ON public.employer_aliases (canonical_employer, alias_employer);
CREATE INDEX IF NOT EXISTS idx_ea_alias_upper
  ON public.employer_aliases (upper(alias_employer));

-- 4. Create merge staging table
CREATE TABLE IF NOT EXISTS staging.donor_merge_candidates (
  id               bigserial PRIMARY KEY,
  keep_id          int NOT NULL,
  merge_id         int NOT NULL,
  match_method     text NOT NULL,
  match_confidence numeric(4,3) NOT NULL,
  anchor_value     text,
  created_at       timestamptz DEFAULT now()
);
CREATE UNIQUE INDEX IF NOT EXISTS idx_dmc_pair
  ON staging.donor_merge_candidates (LEAST(keep_id,merge_id), GREATEST(keep_id,merge_id));

-- 5. Create merge audit table
CREATE TABLE IF NOT EXISTS public.donor_merge_audit (
  id               bigserial PRIMARY KEY,
  kept_person_id   int NOT NULL,
  merged_person_id int NOT NULL,
  match_method     text NOT NULL,
  match_confidence numeric(4,3),
  anchor_value     text,
  merged_at        timestamptz DEFAULT now(),
  authorized_by    text DEFAULT 'Ed Broyhill'
);

REPORT: confirm all tables created.
```

---

## STEP 1 — SEED ALIAS REGISTRY

Find Ed Broyhill's person_id in core.person_spine first:
```sql
SELECT person_id, norm_first, norm_last, zip5, voter_ncid,
       total_contributed, contribution_count, is_active
FROM core.person_spine
WHERE norm_last = 'BROYHILL'
  AND zip5 IN ('27104','27012')
  AND is_active = true
ORDER BY total_contributed DESC NULLS LAST;
```

Report all rows. The person_id with the highest total_contributed
at 525 N Hawthorne / 27104 is Ed's canonical spine record.
Replace :ED_BROYHILL_PERSON_ID below with that person_id.

Then run data/person_name_aliases_seed.sql from the repo:
```
git pull origin main
psql $DATABASE_URL -f data/person_name_aliases_seed.sql \
  -v ED_BROYHILL_PERSON_ID=<person_id>
```

Verify:
```sql
SELECT alias_type, count(*) FROM public.person_name_aliases
WHERE person_id = :ED_BROYHILL_PERSON_ID
GROUP BY 1 ORDER BY 2 DESC;
-- Expected: ~32 total aliases across all types

SELECT count(*) FROM public.employer_aliases
WHERE canonical_employer = 'ANVIL VENTURE GROUP';
-- Expected: 38
```

---

## PASS 1 — STREET NUMBER + ZIP + LAST PREFIX
## (Ed's recommended first move — highest yield, most discriminating)

```sql
-- Build temp table with extracted street numbers from nc_boe_donations_raw
-- ⚠️  NAME FORMAT NOTE:
-- NCBOE stores names in TWO formats in donor_name:
--   Format A: "BROYHILL, ED"   (LAST, FIRST) → norm_last = BROYHILL ✅
--   Format B: "ED BROYHILL"    (FIRST LAST)  → norm_last = ED BROYHILL ❌
-- Format B causes norm_last to contain the full name, breaking all last-prefix joins.
-- We extract true_last from donor_name directly using format detection.
-- This is the canonical last name for ALL matching passes.

CREATE TEMP TABLE tmp_boe_street AS
SELECT
  id                                                           AS boe_id,
  donor_name,
  norm_last,
  norm_first,
  norm_zip5,
  -- True last name: format-aware extraction
  CASE
    WHEN donor_name LIKE '%,%' THEN
      -- "LAST, FIRST" format — everything left of first comma
      upper(trim(split_part(donor_name, ',', 1)))
    ELSE
      -- "FIRST LAST" format — rightmost space-delimited token
      upper(trim(
        split_part(donor_name, ' ',
          array_length(string_to_array(trim(donor_name), ' '), 1)
        )
      ))
  END                                                          AS true_last,
  -- True first name: format-aware extraction
  CASE
    WHEN donor_name LIKE '%,%' THEN
      -- "LAST, FIRST" format — everything right of first comma, first token
      upper(trim(split_part(split_part(donor_name, ',', 2), ' ', 2)))
    ELSE
      -- "FIRST LAST" format — first token
      upper(trim(split_part(trim(donor_name), ' ', 1)))
  END                                                          AS true_first,
  NULLIF(regexp_replace(
    regexp_replace(upper(street_line_1),
      '^\s*(APT|UNIT|SUITE|STE|#)\s*\S+[\s,]+', ''),
    '[^0-9].*', ''), '')                                       AS street_num,
  employer_name,
  amount_numeric,
  date_occurred,
  committee_name,
  committee_sboe_id,
  voter_ncid
FROM public.nc_boe_donations_raw
WHERE transaction_type = 'Individual'
  AND street_line_1 ~ '^\s*\d'
  AND norm_zip5 IS NOT NULL AND norm_zip5 != ''
  AND donor_name IS NOT NULL AND trim(donor_name) != ''
  AND amount_numeric > 0
  AND date_occurred >= '2015-01-01'   -- clean file date range start
  AND date_occurred <= '2026-12-31';  -- clean file date range end

-- Verify name format detection on Ed Broyhill variants:
SELECT donor_name, true_last, true_first, street_num, norm_zip5
FROM tmp_boe_street
WHERE norm_zip5 = '27104' AND street_num = '525'
  AND (donor_name ILIKE '%BROYHILL%')
ORDER BY donor_name;
-- Every row should show true_last = 'BROYHILL' regardless of format
-- true_first should vary: ED, EDGAR, JAMES, J, etc.

CREATE INDEX idx_tmp_boe_sn ON tmp_boe_street (street_num, norm_zip5, LEFT(true_last,3));

-- Build temp table with DataTrust street numbers
CREATE TEMP TABLE tmp_dt_street AS
SELECT
  statevoterid,
  rncid,
  firstname,
  lastname,
  regzip5,
  NULLIF(regexp_replace(
    regexp_replace(upper(registrationaddr1),
      '^\s*(APT|UNIT|SUITE|STE|#)\s*\S+[\s,]+', ''),
    '[^0-9].*', ''), '')                                       AS street_num,
  employer,
  age
FROM public.nc_datatrust
WHERE registrationaddr1 ~ '^\s*\d'
  AND regzip5 IS NOT NULL
  AND lastname IS NOT NULL;

CREATE INDEX idx_tmp_dt_sn ON tmp_dt_street (street_num, LEFT(regzip5,5), LEFT(lastname,3));

-- STAGING PASS 1: street_num + zip5 + last_prefix → match count
CREATE TABLE staging.staging_pass1_street_match AS
SELECT
  b.boe_id,
  b.donor_name                                                 AS boe_name,
  b.norm_last                                                  AS boe_last,
  b.norm_first                                                 AS boe_first,
  b.street_num                                                 AS boe_street_num,
  b.norm_zip5                                                  AS boe_zip,
  b.employer_name                                              AS boe_employer,
  d.statevoterid,
  d.rncid,
  d.firstname                                                  AS dt_first,
  d.lastname                                                   AS dt_last,
  d.street_num                                                 AS dt_street_num,
  LEFT(d.regzip5,5)                                            AS dt_zip,
  d.employer                                                   AS dt_employer,
  d.age                                                        AS dt_age,
  count(*) OVER (
    PARTITION BY b.street_num, b.norm_zip5, LEFT(b.true_last,3)
  )                                                            AS match_count
FROM tmp_boe_street b
JOIN tmp_dt_street d
  ON b.street_num              = d.street_num
  AND LEFT(b.norm_zip5, 5)     = LEFT(d.regzip5, 5)
  AND LEFT(b.true_last, 3)     = LEFT(d.lastname, 3)
-- Exclude already-matched rows
WHERE NOT EXISTS (
  SELECT 1 FROM core.contribution_map cm
  JOIN core.person_spine sp ON sp.person_id = cm.person_id
  WHERE cm.source_system = 'NC_BOE'
    AND cm.source_id = b.boe_id
    AND sp.voter_ncid IS NOT NULL
);

-- Report distribution
SELECT match_count, count(*) AS boe_rows
FROM staging.staging_pass1_street_match
GROUP BY 1 ORDER BY 1;
-- Single matches (match_count=1) are clean auto-promotes
-- Multi-matches go to review queue

SELECT
  count(*) FILTER (WHERE match_count = 1) AS clean_single,
  count(*) FILTER (WHERE match_count > 1) AS ambiguous_multi,
  count(*) AS total_staged
FROM staging.staging_pass1_street_match;
```

**CANARY CHECK — Run before any merge:**
```sql
-- Ed Broyhill should appear in staging with all his variants
SELECT boe_name, boe_street_num, boe_zip, dt_first, dt_last,
       statevoterid, rncid, match_count
FROM staging.staging_pass1_street_match
WHERE boe_street_num = '525' AND boe_zip IN ('27104','27012')
ORDER BY boe_name;
-- Expected: all ED/EDGAR/JAMES EDGAR variants → same statevoterid, same rncid
-- If any variant maps to a different statevoterid: STOP and report
```

Report canary results to Ed before proceeding to merges.

---

## PASS 2 — VOTER_NCID EXACT BRIDGE
## (Zero false positives — run after Pass 1 staging is verified)

```sql
CREATE TABLE staging.staging_pass2_ncid AS
SELECT
  r.id                                                         AS boe_id,
  r.donor_name,
  r.norm_last,
  r.norm_first,
  r.voter_ncid,
  dt.rncid,
  dt.firstname                                                 AS dt_first,
  dt.lastname                                                  AS dt_last,
  LEFT(dt.regzip5,5)                                           AS dt_zip,
  sp.person_id
FROM public.nc_boe_donations_raw r
JOIN public.nc_datatrust dt
  ON dt.statevoterid = r.voter_ncid
JOIN core.person_spine sp
  ON sp.voter_ncid = r.voter_ncid
  AND sp.is_active = true
WHERE r.transaction_type = 'Individual'
  AND r.voter_ncid IS NOT NULL AND r.voter_ncid != ''
  AND r.amount_numeric > 0
  AND r.date_occurred >= '2015-01-01'
  AND r.date_occurred <= '2026-12-31'
  AND NOT EXISTS (
    SELECT 1 FROM core.contribution_map cm
    WHERE cm.source_system = 'NC_BOE' AND cm.source_id = r.id
  );

SELECT count(*) AS ncid_matches FROM staging.staging_pass2_ncid;
-- Report count before any writes
```

---

## PASS 3 — EMPLOYER NAME + SIC + LAST PREFIX
## (Captures top 30% major donors filing from office)

```sql
-- Normalize BOE employer against employer_aliases table
CREATE TABLE staging.staging_pass3_employer AS
SELECT
  b.boe_id,
  b.donor_name,
  b.norm_last,
  b.norm_first,
  b.norm_zip5,
  b.boe_employer,
  ea.canonical_employer,
  ea.sic_code,
  d.statevoterid,
  d.rncid,
  d.firstname                                                  AS dt_first,
  d.lastname                                                   AS dt_last,
  LEFT(d.regzip5,5)                                            AS dt_zip,
  count(*) OVER (
    PARTITION BY ea.canonical_employer, LEFT(b.true_last,3)
  )                                                            AS match_count
FROM tmp_boe_street b
JOIN public.employer_aliases ea
  ON upper(trim(b.boe_employer)) = upper(trim(ea.alias_employer))
JOIN public.nc_datatrust d
  ON LEFT(d.lastname, 3) = LEFT(b.true_last, 3)
  AND upper(trim(d.employer)) IN (
    SELECT upper(trim(alias_employer))
    FROM public.employer_aliases
    WHERE canonical_employer = ea.canonical_employer
  )
WHERE b.boe_employer IS NOT NULL
  AND b.boe_employer NOT IN ('RETIRED','SELF-EMPLOYED','N/A','','NO EMPLOYER')
  AND NOT EXISTS (
    SELECT 1 FROM staging.staging_pass1_street_match s
    WHERE s.boe_id = b.boe_id AND s.match_count = 1
  );

SELECT match_count, count(*) FROM staging.staging_pass3_employer GROUP BY 1 ORDER BY 1;
```

---

## PASS 4 — FEDERAL CANDIDATE CROSS-REFERENCE
## (Tillis, Budd, Hudson, Foxx — two independent government filings)

```sql
-- Find BOE donors who also appear in FEC giving to NC federal incumbents
CREATE TABLE staging.staging_pass4_federal AS
SELECT
  b.boe_id,
  b.donor_name                                                 AS boe_name,
  b.norm_last,
  b.norm_first,
  b.boe_employer,
  f.contributor_name                                           AS fec_name,
  f.norm_last                                                  AS fec_last,
  f.contributor_employer                                       AS fec_employer,
  f.contributor_zip                                            AS fec_zip,
  f.transaction_amount,
  f.transaction_date,
  f.committee_name                                             AS fec_committee,
  -- Employer similarity score
  similarity(upper(coalesce(b.boe_employer,'')),
             upper(coalesce(f.contributor_employer,'')))       AS emp_similarity,
  count(*) OVER (
    PARTITION BY LEFT(b.true_last,3), LEFT(f.contributor_zip,5)
  )                                                            AS match_count
FROM tmp_boe_street b
JOIN public.fec_party_committee_donations f
  ON LEFT(b.true_last, 3)  = LEFT(f.norm_last, 3)
  AND LEFT(b.norm_zip5, 5) = LEFT(f.contributor_zip, 5)
  AND (
    similarity(upper(coalesce(b.boe_employer,'')),
               upper(coalesce(f.contributor_employer,''))) > 0.5
    OR b.street_num = f.norm_street_num
  )
  AND ABS(b.date_occurred - f.transaction_date) < 730
  AND b.date_occurred >= '2015-01-01'
  AND b.date_occurred <= '2026-12-31'
  -- NC federal incumbent committees
  AND f.committee_name ILIKE ANY (ARRAY[
    '%TILLIS%','%BUDD%','%HUDSON%','%FOXX%','%FOX%','%BURR%',
    '%MEADOWS%','%WALKER%','%MCHENRY%','%BISHOP%'
  ])
WHERE b.boe_employer NOT IN ('RETIRED','SELF-EMPLOYED','N/A','')
  AND NOT EXISTS (
    SELECT 1 FROM staging.staging_pass1_street_match s
    WHERE s.boe_id = b.boe_id AND s.match_count = 1
  );

SELECT count(*) AS federal_cross_matches FROM staging.staging_pass4_federal
WHERE emp_similarity > 0.5 AND match_count = 1;
```

---

## PASS 5 — COMMITTEE LOYALTY FINGERPRINT
## (Same committee cluster 3+ cycles = same donor regardless of name)
## Uses: committee_registry (10,975 rows) + ncsbe_candidates (55,985 rows)
## Full chain: nc_boe_donations_raw → committee_registry → ncsbe_candidates
## Gives: committee_type, candidate_name, office, district, county per donation

```sql
-- Build committee fingerprint per name+zip cluster
CREATE TABLE staging.staging_pass5_fingerprint AS
WITH fingerprints AS (
  SELECT
    r.norm_last,
    LEFT(r.norm_zip5, 5)                                       AS zip5,
    r.committee_sboe_id,
    cr.committee_name,
    cr.committee_type,
    cr.candidate_name                                          AS committee_candidate,
    nc.contest_name                                            AS office,
    nc.county                                                  AS candidate_county,
    count(DISTINCT EXTRACT(year FROM r.date_occurred))         AS cycles,
    sum(r.amount_numeric)                                      AS total_given
  FROM public.nc_boe_donations_raw r
  -- Bridge to committee registry (sboe_id → committee type + candidate)
  LEFT JOIN public.committee_registry cr
    ON cr.sboe_id = r.committee_sboe_id
  -- Bridge to candidate registry (candidate name → office + district + cycle)
  LEFT JOIN public.ncsbe_candidates nc
    ON upper(trim(nc.candidate_name)) = upper(trim(cr.candidate_name))
    AND nc.party ILIKE '%REP%'
  WHERE r.transaction_type = 'Individual'
    AND r.norm_last IS NOT NULL
    AND r.norm_zip5 IS NOT NULL
    AND r.committee_sboe_id IS NOT NULL
    AND r.date_occurred >= '2015-01-01'
    AND r.date_occurred <= '2026-12-31'
  GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
  HAVING count(DISTINCT EXTRACT(year FROM r.date_occurred)) >= 3
),
shared AS (
  SELECT
    f1.norm_last                                               AS name_a,
    f2.norm_last                                               AS name_b,
    f1.zip5,
    count(DISTINCT f1.committee_sboe_id)                       AS shared_committees,
    array_agg(DISTINCT f1.committee_sboe_id ORDER BY f1.committee_sboe_id) AS committee_ids
  FROM fingerprints f1
  JOIN fingerprints f2
    ON f1.committee_sboe_id = f2.committee_sboe_id
    AND f1.zip5             = f2.zip5
    AND f1.norm_last        != f2.norm_last
    AND f1.norm_last        < f2.norm_last
  GROUP BY 1, 2, 3
  HAVING count(DISTINCT f1.committee_sboe_id) >= 2
)
SELECT * FROM shared ORDER BY shared_committees DESC;

SELECT name_a, name_b, zip5, shared_committees
FROM staging.staging_pass5_fingerprint
ORDER BY shared_committees DESC
LIMIT 30;
-- Report top 30 name pairs sharing 2+ anchor committees
```

---

## PASS 6 — CANONICAL FIRST NAME / NICKNAME NORMALIZATION

```sql
-- Uses existing name_variants table (public.name_variants)
-- Adds: canonical first name resolution before name+zip rematch
CREATE TABLE staging.staging_pass6_nickname AS
SELECT
  b.boe_id,
  b.donor_name,
  b.norm_last,
  b.norm_first,
  nv.canonical                                                 AS canonical_first,
  b.norm_zip5,
  d.statevoterid,
  d.rncid,
  d.firstname,
  d.lastname,
  count(*) OVER (
    PARTITION BY nv.canonical, b.norm_last, b.norm_zip5
  )                                                            AS match_count
FROM tmp_boe_street b
JOIN public.name_variants nv ON nv.nickname = b.norm_first
JOIN public.nc_datatrust d
  ON d.lastname  = b.norm_last
  AND LEFT(d.regzip5,5) = LEFT(b.norm_zip5,5)
  AND (d.firstname = nv.canonical
       OR EXISTS (
         SELECT 1 FROM public.name_variants nv2
         WHERE nv2.nickname = d.firstname
           AND nv2.canonical = nv.canonical
       ))
WHERE NOT EXISTS (
  SELECT 1 FROM staging.staging_pass1_street_match s
  WHERE s.boe_id = b.boe_id AND s.match_count = 1
)
  AND NOT EXISTS (
  SELECT 1 FROM staging.staging_pass2_ncid s2
  WHERE s2.boe_id = b.boe_id
);

SELECT count(*) AS nickname_matches FROM staging.staging_pass6_nickname WHERE match_count = 1;
```

---

## PASS 7 — REVERSE CHRONOLOGICAL DATE SCAN
## (Most recent filing first — current employer/address most reliable)

```sql
-- For remaining unmatched BOE rows, try last+zip match ordered newest first
-- Assigns match from most recent transaction backward
CREATE TABLE staging.staging_pass7_recency AS
SELECT DISTINCT ON (b.norm_last, LEFT(b.norm_zip5,5))
  b.boe_id,
  b.donor_name,
  b.norm_last,
  b.norm_first,
  b.norm_zip5,
  b.date_occurred,
  d.statevoterid,
  d.rncid,
  d.firstname,
  count(*) OVER (
    PARTITION BY b.norm_last, LEFT(b.norm_zip5,5)
  )                                                            AS match_count
FROM tmp_boe_street b
JOIN public.nc_datatrust d
  ON d.lastname          = b.norm_last
  AND LEFT(d.regzip5,5)  = LEFT(b.norm_zip5,5)
WHERE NOT EXISTS (
  SELECT 1 FROM staging.staging_pass1_street_match s WHERE s.boe_id = b.boe_id AND s.match_count=1
) AND NOT EXISTS (
  SELECT 1 FROM staging.staging_pass2_ncid s2 WHERE s2.boe_id = b.boe_id
) AND NOT EXISTS (
  SELECT 1 FROM staging.staging_pass6_nickname s6 WHERE s6.boe_id = b.boe_id AND s6.match_count=1
)
ORDER BY b.norm_last, LEFT(b.norm_zip5,5), b.date_occurred DESC;

SELECT match_count, count(*) FROM staging.staging_pass7_recency GROUP BY 1 ORDER BY 1;
```

---

## CANARY VERIFICATION (run after all passes staged)

```sql
-- Ed Broyhill full profile check
-- Expected: all 32 name variants resolve to 1 statevoterid, 1 rncid
SELECT boe_name, statevoterid, rncid, match_count, match_method
FROM (
  SELECT boe_name, statevoterid, rncid, match_count, 'pass1_street' AS match_method
  FROM staging.staging_pass1_street_match
  WHERE boe_street_num = '525' AND boe_zip IN ('27104','27012')
  UNION ALL
  SELECT donor_name, statevoterid, rncid, 1, 'pass2_ncid'
  FROM staging.staging_pass2_ncid
  WHERE norm_zip5 = '27104'
    AND norm_last = 'BROYHILL'
) all_matches
ORDER BY match_method, boe_name;

-- Total attributed giving after rollup
SELECT
  sp.person_id,
  sp.norm_first, sp.norm_last, sp.zip5,
  count(DISTINCT cm.source_id)    AS total_transactions,
  round(sum(cm.amount))           AS total_giving
FROM core.person_spine sp
JOIN core.contribution_map cm ON cm.person_id = sp.person_id
WHERE sp.norm_last = 'BROYHILL'
  AND sp.zip5 = '27104'
  AND sp.is_active = true
GROUP BY 1,2,3,4
ORDER BY total_giving DESC;
-- Expected: 1 active row, total_giving approaching $1,016,573
```

---

## AUTHORIZATION GATES

| Action | Requires |
|---|---|
| CREATE staging tables | No auth needed |
| SELECT / staging inserts | No auth needed |
| UPDATE core.person_spine | "I authorize this action" |
| UPDATE core.contribution_map | "I authorize this action" |
| Merge person_ids (mark merged_into) | "I authorize this action" |

**SEQUENCE: Run all staging passes → show Ed all counts + canary → wait for authorization → execute merges in one transaction.**

---

## REPORT BACK FORMAT

After all passes staged, report:

| Pass | Method | Clean single matches | Ambiguous (review) |
|---|---|---|---|
| Pass 1 | Street num + zip + last prefix | ? | ? |
| Pass 2 | voter_ncid exact | ? | 0 |
| Pass 3 | Employer + SIC + last prefix | ? | ? |
| Pass 4 | Federal candidate cross-ref | ? | ? |
| Pass 5 | Committee loyalty fingerprint | ? | ? |
| Pass 6 | Nickname normalization | ? | ? |
| Pass 7 | Recency / last+zip | ? | ? |
| **TOTAL** | | **?** | **?** |

Plus canary result for Ed Broyhill.

---

*Prepared by Perplexity AI — March 31, 2026*
*Full 7-pass strategy per Ed Broyhill's instructions*
*Street number anchor is Pass 1 per Ed's recommendation*
