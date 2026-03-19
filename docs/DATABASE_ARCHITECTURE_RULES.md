# Database Architecture Rules — AI Instructions

**Authority:** Give this instruction to any AI touching the BroyhillGOP database.

---

## Core Rule (Post–Opus 4.6)

**Raw donation tables are frozen. All intelligence lives in the relationship layer. Views are the query interface.**

- **Do NOT** modify raw donation tables (fec_donations, fec_party_committee_donations, nc_boe_donations_raw) for enrichment or filtering.
- **Do** add new tables, views, and relationship layers for intelligence.
- **Do** query via enrichment views (v_fec_donations_enriched, v_ncboe_donations_enriched, v_fec_party_donations_enriched) when candidate beneficiary names or entity context are needed.

---

## Entity Relationship Layer (Opus 4.6)

| Table | Rows | Purpose |
|-------|------|---------|
| `political_entity_master` | 1,947 | Every R committee/PAC/party org profiled |
| `entity_office_influence` | 1,985 | Maps entities to offices they serve |
| `entity_candidate_links` | 1,139 | Links entities to specific candidates |
| `fec_committee_master_staging` | 35,521 | FEC master committee file 2020–2026 |

**Superseded:** `committee_party_map` (2,765 rows) is effectively superseded by `political_entity_master`.

---

## Donation Tables (100% Republican Post–Opus 4.6)

Opus 4.6 removed D/I donations:

- `fec_donations` — 36,152 removed
- `fec_party_committee_donations` — 40,034 removed
- `nc_boe_donations_raw` — 41 removed

All three tables are now 100% Republican. `party_flag` columns on these tables are moot.

---

## Enrichment Views (Query Interface)

| View | Purpose |
|------|---------|
| `v_fec_donations_enriched` | FEC donations JOINed through entity layer → candidate beneficiary names |
| `v_ncboe_donations_enriched` | NCBOE donations JOINed through entity layer |
| `v_fec_party_donations_enriched` | FEC party donations JOINed through entity layer |

---

## Reconciliation with Earlier Work

| Earlier work | Status |
|--------------|--------|
| `committee_party_map` | Superseded by `political_entity_master` |
| `party_flag` columns | Moot — all non-R rows deleted |
| `ncsbe_candidates` column shift fix (phone/email/filing_date remap) | **Still valid** — 15K phones, 12K emails preserved |
| FEC voter matcher, migration 059 (committee separation) | Check against `norm.fec_individual` / `raw.fec_donations` — may differ from public fec_donations |
| `donor_contribution_map`, `core.person_spine` | See docs/CANONICAL_TABLES_AUDIT.md |

---

## RFC-001 (Identity Layer)

For identity resolution and spine rebuilds: follow docs/CLAUDE_INSTRUCTIONS_RFC001_REBUILD.md. Do NOT seed `core.person_spine` from golden_records or person_master.
