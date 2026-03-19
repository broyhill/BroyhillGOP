# Donor Selection Algorithm — What Must Be Built

**Status:** NOT implemented. This spec defines the quantifiable algorithm the AI needs.

---

## The Problem

1. **Dinner for 50** — Candidate needs 50 invites. Search "A++ and A+" returns 45. We stop at 45 and leave seats empty. Wrong: use **rank** (top 50), not tier.

2. **Office-specific giving** — 45 A++/A+ donors in district, but 30 never gave to this office. They're high donors elsewhere. Wrong: filter by **giving to this office**, not total giving.

3. **Intent** — Reward past donors vs. cultivate high-capacity non-donors. The AI must know which.

---

## Current Schema Gaps

| Table | Has | Missing |
|-------|-----|---------|
| `nc_boe_donations_raw` | committee_name, committee_sboe_id, candidate_referendum_name, amount_numeric | office_type, district, county per donation |
| `donor_contribution_map` | committee_id, golden_record_id | candidate_id (0), office filter, amount column name varies |
| `vw_donor_analysis_consolidated` | total_amount per donor (all races) | office-specific totals, rank |
| `boe_committee_candidate_map` | ~1,033 rows committee→candidate | coverage unknown; no office_type on map |

---

## What Must Be Built

### 1. Committee → Office Mapping

```
committee_sboe_id (or committee_name) → office_type, district, county
```

Source: NCSBE committee registry, candidate_profiles, or parsed committee names. Populate a table:

```sql
CREATE TABLE IF NOT EXISTS public.donor_committee_office_map (
  committee_sboe_id TEXT PRIMARY KEY,
  committee_name TEXT,
  office_type TEXT,      -- Sheriff, School Board, State House, etc.
  district_id TEXT,
  county TEXT,
  source TEXT
);
```

### 2. Donor + Office-Specific Totals View

```sql
-- Donor totals BY office (office_type + district + county)
-- Enables: "has given to this office" and "amount given to this office"
CREATE OR REPLACE VIEW public.vw_donor_office_totals AS
SELECT
  COALESCE(d.voter_ncid, 'noid_' || md5(...)) AS donor_key,
  d.norm_last, d.canonical_first, d.norm_zip5, d.norm_city,
  m.office_type, m.district_id, m.county,
  SUM(d.amount_numeric) AS total_to_this_office,
  COUNT(*) AS donation_count_to_office,
  MIN(d.date_occurred) AS first_donation_to_office,
  MAX(d.date_occurred) AS last_donation_to_office
FROM public.nc_boe_donations_raw d
JOIN public.donor_committee_office_map m ON d.committee_sboe_id = m.committee_sboe_id
WHERE d.transaction_type = 'Individual' AND d.amount_numeric > 0
GROUP BY donor_key, d.norm_last, d.canonical_first, d.norm_zip5, d.norm_city,
         m.office_type, m.district_id, m.county;
```

### 3. Selection Function (Quantifiable Algorithm)

```sql
-- p_candidate_id: whose dinner / whose office
-- p_office_type, p_district, p_county: scope (from candidate_profiles)
-- p_capacity: 50 seats
-- p_intent: 'reward' (only past donors) | 'cultivate' (include high-capacity non-donors)
-- p_geography: 'in_district' | 'any'
CREATE OR REPLACE FUNCTION get_event_invite_list(
  p_candidate_id UUID,
  p_office_type TEXT,
  p_district TEXT,
  p_county TEXT,
  p_capacity INT,
  p_intent TEXT DEFAULT 'reward',
  p_geography TEXT DEFAULT 'in_district'
) RETURNS TABLE (
  donor_key TEXT,
  norm_last TEXT,
  canonical_first TEXT,
  total_to_this_office NUMERIC,
  total_all_races NUMERIC,
  in_district BOOLEAN,
  rank_in_scope INT
) AS $$
  -- If reward: filter WHERE total_to_this_office > 0
  -- If cultivate: include donors with total_to_this_office = 0 but total_all_races high
  -- Order by: reward → total_to_this_office DESC; cultivate → total_all_races DESC
  -- Filter geography: dt_county = p_county (or district match) when p_geography = 'in_district'
  -- LIMIT p_capacity
$$;
```

### 4. AI Decision Logic (Pseudocode)

```
IF event_type = 'dinner' AND capacity = 50:
  intent = user_says_reward ? 'reward' : 'cultivate'
  result = get_event_invite_list(candidate_id, office_type, district, county, 50, intent, 'in_district')
  -- Returns exactly 50 rows (or fewer if not enough in scope)
  -- Rank-based, not tier-based
  -- Office-specific filter applied
```

---

## Build Order

1. Populate `donor_committee_office_map` (committee_sboe_id → office_type, district, county).
2. Create `vw_donor_office_totals`.
3. Implement `get_event_invite_list`.
4. Wire AI/orchestrator to call the function with candidate context and intent.

---

## References

- docs/DONOR_RANGES_AND_LIMITS_RULES.md
- docs/RFC-001-ARCHITECTURE-REVIEW.md (boe_committee_candidate_map, candidate_id gap)
- NC_BOE_COMPLETE_SCHEMA_MAPPING.md (office_type, office_level on candidate side)
