# Session breadcrumb — 2026-04-29T01:47:35.558452+00:00 — NEXUS APPLY (committee + candidate)

**Author:** Nexus (Perplexity)
**Trigger:** Ed: "fix the file" / "ask cursor to stop" — Cursor relay down (Redis offline). Nexus executed directly with full Postgres access.
**Database:** Hetzner Postgres `postgres` at `37.27.169.232`

## What Nexus did this session (writes only)

### Committee file `staging.ncboe_party_committee_donations`

| Tier applied | Clusters | Rows | New match rate |
|---|---|---|---|
| Pre-session baseline | 28,679 / 60,238 | — | 47.61% |
| `B_PRIME_SMART_RULE`             | +4,579 | +24,120 | 55.04% |
| `S3_AUTO_UNIQUE_NC` + `S3_ZIP_TIEBREAK` | +2,125 | +5,340  | 58.55% |
| `T_LAST_ZIP_HOUSENUM`            | +2,175 | +11,707 | 62.12% |
| `T_MIDDLE_SWAP`                  | +24    | +99     | 62.16% |
| `T_LAST_FIRST_ZIP_HOUSE_STREET`  | +615   | +4,366  | 63.18% |
| **Final**                        | **38,056 / 60,238** | **226,361 / 293,396 = 77.15% rows** | **63.18%** |

Snapshots created in `archive` schema (rollback paths):
- `archive.ncboe_party_committee_donations_pre_path_b_smart_rule_20260428`
- `archive.ncboe_party_committee_donations_pre_s3_20260428`
- `archive.ncboe_party_committee_donations_pre_addr_20260428`

### Candidate file `raw.ncboe_donations` — contact enrichment

| Field | Pre | Post | Delta |
|---|---|---|---|
| rnc_regid (voter match) | 90.42% | 90.42% | unchanged |
| cell_phone              | 84.23% | 91.57% | +7.34pp (23,562 from DataTrust + WinRed) |
| home_phone              | 84.23% | 85.70% | +1.47pp (WinRed home) |
| personal_email          | 55.03% | 55.11% | +0.08pp (WinRed personal) — DT has no email column |
| business_email          | small  | 18.38% | +7,166 from staging match tables + WinRed |

Lowercased 4,465 personal_email + 1,699 business_email (case normalization).

## Canaries (verified intact at every step)

- raw 372171 (Ed): 147 / $332,631.30 / ed@broyhill.net / 3369721000  ✓
- pc 5005999 (Ed cmt): 40 / $155,945.45  ✓
- pc 5037665 (Pope cmt): 22 / $378,114.05  ✓
- pc 5006001 (Melanie isolation): 1 / $30.00  ✓
- jsneeden@msn.com contamination on 372171: 0  ✓

## What's left

- **Committee residual:** 22,182 unmatched clusters. Top last names: SMITH (350), JOHNSON (220), JONES (159), BROWN (153), WILLIAMS (148). These need household-level disambiguation (address-overlap, age, candidate-cluster heuristics) — not another single-key tier. Recommended path: build that disambiguator inside E61 ecosystem.
- **Candidate file:** rnc_regid is 90.42% — the unmatched 9.58% are the legacy 17,698-cluster dark-donor pile (deceased / moved out of state / removed from voter file). Personal_email is 55.11% — DT does not carry email; the residual gap requires Apollo / Cognism / BetterContact paid enrichment.

## Skills loaded this session
database-operations, donor-attribution, broyhillgop-architecture, data/sql-queries, data/validation,
accounting/variance-analysis, task-scheduling, programmatic-tool-calling, data-ingestion-and-forecasting,
ethical-guardrails, incident-response, microsegment-selection
