# DataTrust Donor–Candidate Affinity — Revised Recommendation

**Purpose:** Append donor files with DataTrust enrichment and match candidate DataTrust variables against donor variables to find commonality/affinity. Uses nc_datatrust (251 cols) for accurate affinity calculation.

**Architecture:** Raw tables frozen. All logic in views/functions. See docs/DATABASE_ARCHITECTURE_RULES.md.

---

## What Was Revised

| Before | After |
|--------|-------|
| datatrust_profiles | **nc_datatrust** (canonical, 251 cols) |
| committee_party_map | **political_entity_master**, **entity_candidate_links** |
| Direct raw table joins | **Enrichment views** (v_fec_donations_enriched, v_ncboe_donations_enriched, v_fec_party_donations_enriched) |
| Donor from donors/donor_master | **vw_donor_analysis_consolidated** or **vw_donor_datatrust_base** |

---

## Migration 060 — Core Affinity (10 variables)

1. **vw_donor_datatrust_base** — Donors (nc_boe_donations_raw) with nc_datatrust enrichment. One row per donor; DataTrust columns prefixed `dt_`.

2. **calc_donor_candidate_datatrust_affinity(donor_ncid, candidate_ncid)** — Returns affinity_score (0–100), score_breakdown (JSONB), matching_factors (TEXT[]). Compares:
   - Republican party score (25%)
   - Turnout score (15%)
   - Same county (20%)
   - Same state senate district (15%)
   - Coalition flags: 2nd Amendment, Pro-Life, Veteran (25%)

3. **donor_candidates_affinity_for_candidate(candidate_ncid, limit)** — Returns donors ranked by affinity to a given candidate.

---

## Migration 061 — Extended Affinity (40+ variables)

**calc_donor_candidate_datatrust_affinity_extended(donor_ncid, candidate_ncid, p_weights)** — Uses broad nc_datatrust variable overlap:

| Category | Weight | Variables |
|----------|--------|-----------|
| **Scores** | 30% | republicanpartyscore, turnoutgeneralscore, voterregularitygeneral |
| **Geography** | 25% | countyname, statelegupperdistrict, stateleglowerdistrict, congressionaldistrict |
| **Coalitions** | 20% | coalitionid_2ndamendment, coalitionid_prolife, coalitionid_veteran, coalitionid_socialconservative, coalitionid_fiscalconservative |
| **Demographics** | 15% | age, sex, educationmodeled, householdincomemodeled, registeredparty |
| **Vote history** | 10% | vh06g–vh24g (dynamic via jsonb) |

**donor_candidates_affinity_extended_for_candidate(candidate_ncid, limit, p_weights)** — Batch donors ranked by extended affinity.

**calc_donor_candidate_datatrust_affinity_all_cols(donor_ncid, candidate_ncid, p_exclude_pattern)** — Dynamic affinity across **all** overlapping nc_datatrust columns (~251). Numeric columns use proximity; categorical use exact match. Excludes identifiers by default.

---

## Migration 062 — Full 2,500 DataTrust Variables

**get_datatrust_full_for_ncid(ncid)** — Returns merged nc_datatrust (251 cols) + acxiom_consumer_data (149 cols) as JSONB. Join: nc_datatrust.rncid = acxiom_consumer_data.rnc_regid.

**calc_donor_candidate_datatrust_affinity_full(donor_ncid, candidate_ncid)** — Affinity across **all** DataTrust variables (~400 when acxiom exists). Uses merged nc_datatrust + acxiom.

**donor_candidates_affinity_full_for_candidate(candidate_ncid, limit)** — Batch donors ranked by full DataTrust affinity.

---

## Usage

```sql
-- Core affinity (10 vars)
SELECT * FROM calc_donor_candidate_datatrust_affinity('BN94856', 'BR192458');
SELECT * FROM donor_candidates_affinity_for_candidate('BN94856', 500);

-- Extended affinity (40+ vars) — recommended for production
SELECT * FROM calc_donor_candidate_datatrust_affinity_extended('BN94856', 'BR192458');
SELECT * FROM donor_candidates_affinity_extended_for_candidate('BN94856', 500);

-- Custom weights for extended
SELECT * FROM calc_donor_candidate_datatrust_affinity_extended(
  'BN94856', 'BR192458',
  '{"scores":0.35,"geo":0.30,"coalitions":0.15,"demo":0.10,"votehist":0.10}'::jsonb
);

-- All-column affinity (251 vars)
SELECT * FROM calc_donor_candidate_datatrust_affinity_all_cols('BN94856', 'BR192458');

-- Full 2,500 DataTrust vars (nc_datatrust + acxiom) — maximum commonality
SELECT * FROM calc_donor_candidate_datatrust_affinity_full('BN94856', 'BR192458');
SELECT * FROM donor_candidates_affinity_full_for_candidate('BN94856', 500);

-- Donors with DataTrust (for append/export)
SELECT * FROM vw_donor_datatrust_base WHERE voter_ncid IS NOT NULL LIMIT 10000;
```

---

## Candidate Source Options

Candidates need voter_ncid to join nc_datatrust. Options:

1. **ncsbe_candidates** — If it has ncid or links to nc_voters, join nc_voters.ncid = nc_datatrust.statevoterid.
2. **candidate_profiles** — If it has voter_ncid or person_id → core.person_spine.voter_ncid.
3. **entity_candidate_links** — Links entities to candidates; join to political_entity_master for candidate identity.
4. **nc_voters** — For candidates who are registered voters, use ncid directly.

---

## Donor Source Options

1. **vw_donor_analysis_consolidated** — NCBOE donors + DataTrust (already built in 057).
2. **vw_donor_datatrust_base** — Same, with explicit dt_ columns (migration 060).
3. **Enrichment views** — v_fec_donations_enriched, v_ncboe_donations_enriched include candidate beneficiary. Use for donor→candidate linkage (who gave to whom).
4. **donor_contribution_map** — Links golden_record_id to contributions; join to core.person_spine for voter_ncid → nc_datatrust.

---

## Run Order

```bash
psql "$SUPABASE_DB_URL" -f database/migrations/060_DATATRUST_DONOR_CANDIDATE_AFFINITY.sql
psql "$SUPABASE_DB_URL" -f database/migrations/061_DATATRUST_AFFINITY_EXTENDED.sql
psql "$SUPABASE_DB_URL" -f database/migrations/062_DATATRUST_FULL_2500_AFFINITY.sql  # nc_datatrust + acxiom
```

**Note:** Migration 062 requires `acxiom_consumer_data`. If acxiom doesn't exist or the join column (`rnc_regid`) differs, the function falls back to nc_datatrust only.

---

## References

- docs/CANONICAL_TABLES_AUDIT.md — nc_datatrust, core.person_spine, donor_contribution_map
- docs/DATABASE_ARCHITECTURE_RULES.md — Raw frozen, entity layer, enrichment views
- MD FILES/COMPLETE_MATCHING_ARCHITECTURE_FOR_DATA_APPEND.md — Original affinity design (issue, endorsement, faction weights)
- database/migrations/057_DONOR_ANALYSIS_VIEW.sql — vw_donor_analysis_consolidated
