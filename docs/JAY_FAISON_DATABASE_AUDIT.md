# Jay Faison Database Audit — Missing & Misclassified

**Date:** 2025-03-12  
**Purpose:** Identify what's wrong with donor totals and classification.

---

## Corrected 10-Year Total (2015–2025)

| Source | Amount | Notes |
|--------|--------|-------|
| NCBOE (nc_boe_donations_raw) | $303,007 | NC state candidate/committee |
| FEC god (fec_god_contributions) | $206,200 | Federal candidate committees |
| FEC party (fec_party_committee_donations) | $1,260,693 | Federal party committees |
| **TOTAL** | **$1,769,900** | |

**Earlier wrong answer:** $1,309,000 — understated by ~$460K because fec_party date filter failed and/or sources were not combined correctly.

---

## What Was Missing

### 1. FEC Tables Not Queried

| Table | Rows (Faison) | Total | Status |
|-------|---------------|-------|--------|
| fec_donations | 221 | $1,296,550 | Queried but relationship to fec_god/fec_party unclear |
| fec_god_contributions | 63 | $206,200 | Candidate contributions |
| fec_party_committee_donations | 237 | $1,260,693 | Party committee contributions |
| fec_2017_2018_a_staging | 0 | $0 | No Faison; may be different cycle/scope |
| ncgop_god_contributions | 0 | $0 | No Faison; entity_name structure differs |

**Gap:** fec_donations ($1.3M) ≠ fec_god + fec_party ($1.47M). fec_donations is $170K less. Either fec_donations is a subset, or fec_god/fec_party overlap with each other. Need source-of-truth mapping.

### 2. donor_contribution_map Not Used

- Has contribution_receipt_amount, source_system (fec_god, fec_party, NC_BOE)
- Links via golden_record_id — but donor_golden_records does not exist in this DB
- Cannot resolve golden_record_id → donor name without person_spine or equivalent
- **683,638 NC_BOE rows** in donor_contribution_map — may include Faison but we can't query by name

### 3. Date Filter Failures

- fec_party_committee_donations.transaction_date is TEXT in MMDDYYYY format
- `BETWEEN '2015-01-01' AND '2025-12-31'` fails on text — returns 0
- Must use `to_date(transaction_date, 'MMDDYYYY')` for date filter
- **Impact:** Initial query understated fec_party by $1.26M (returned 0)

### 4. NCBOE Slight Variance

- With date filter 2015–2025: $303,007
- Without date filter: $308,007 (includes 2026 rows)
- Minor — 2 donations in 2026

---

## What Was Misclassified

### 1. Name Variants — Same Person, Multiple Rows

Jay Faison appears as:
- FAISON, JAY
- FAISON, JAY W
- FAISON, JAY W.
- FAISON, JAY W. MR.
- FAISON, JAY WINTERS
- FAISON, JAY WINTERS MR.
- FAISON, JAY MR.

**Impact:** Must use `LIKE 'FAISON, JAY%'` to capture all. Excluding variants undercounts.

### 2. Different People With "FAISON" in Name

| Name | Total | Included by mistake? |
|------|-------|----------------------|
| KUESTER, FAISON | $82,363 | YES — "%%FAISON%%" matches; different person |
| FAISON, OLGA | $116,500+ | Possibly spouse; user may want separate |
| FAISON, CAMERON JR | $500 | Son; different person |
| FAISON, CRYSTAL | $250 | Different person |
| FAISON, JASON | $2,000 | Different person |

**Impact:** Broad filter `%%FAISON%%` inflates total. Must use `FAISON, JAY%` or equivalent to restrict to Jay.

### 3. Identity Resolution — NCBOE

- Same person: 10 rows (different zip/city/name spelling)
- Zips: 28204, 28211, 28273, (null)
- vw_donor_analysis_consolidated groups by voter_ncid or hash — but multiple zips = multiple groups
- **Impact:** Donor may be split across groups in aggregated views

### 4. Source Overlap Ambiguity

- fec_god: candidate committee contributions (Schedule A)
- fec_party: party committee contributions
- fec_donations: unknown — could be union, subset, or different pipeline
- **No documentation** of which tables are canonical or how they relate

---

## Recommendations

1. **Document FEC table relationships** — fec_donations vs fec_god vs fec_party; which is source of truth.
2. **Fix fec_party date handling** — cast transaction_date for filtering or add proper date column.
3. **Standardize name matching** — use `FAISON, JAY%` for Jay; exclude KUESTER, FAISON and other non-Jay Faisons.
4. **Resolve donor_contribution_map** — restore or build golden_record → name mapping so dcm can be queried by donor.
5. **Identity resolution** — merge NCBOE rows for same person (name + zip variants) before aggregation.
6. **Single donor lookup API** — one function that queries all sources, dedupes, and returns correct total.

---

## Reference Queries (Corrected)

```sql
-- NCBOE
SELECT SUM(amount_numeric) FROM nc_boe_donations_raw
WHERE norm_last = 'FAISON' AND (canonical_first ILIKE '%jay%' OR norm_first ILIKE '%jay%')
AND transaction_type = 'Individual' AND amount_numeric > 0
AND date_occurred BETWEEN '2015-01-01' AND '2025-12-31';

-- FEC god
SELECT SUM(contribution_receipt_amount) FROM fec_god_contributions
WHERE contributor_name LIKE 'FAISON, JAY%'
AND contribution_receipt_date BETWEEN '2015-01-01' AND '2025-12-31';

-- FEC party (note: to_date for MMDDYYYY)
SELECT SUM(transaction_amount) FROM fec_party_committee_donations
WHERE contributor_name LIKE 'FAISON, JAY%' AND contributor_city = 'CHARLOTTE'
AND to_date(transaction_date, 'MMDDYYYY') BETWEEN '2015-01-01' AND '2025-12-31';
```
