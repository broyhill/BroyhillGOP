# Donor Ranges & Contribution Limits — Rules for Cursor

**Authority:** Do not publish or hardcode donation ranges until derived from actual data. Respect contribution limits by office and election.

---

## Rule 1: Donation Ranges — Derive, Don't Invent

**Do NOT** publish or use donor tiers (e.g., "$25–$500", "$500–$10K", "$10K+") until:

1. Query actual data: `nc_boe_donations_raw`, `donor_contribution_map`, FEC tables
2. Compute percentiles, histograms, or natural breakpoints by office type and cycle
3. Document the source query and date of derivation

**Wrong:** Hardcoding `A: $2,500`, `B+: $1,500` in schemas or docs without data backing.

**Right:** Run `scripts/analyze_donor_percentiles.py` against Supabase to compute percentiles and top-donor spread. Use output to define tier boundaries. Then document.

---

## Rule 2: Contribution Limits — Office & Election Matter

### Federal (FEC) — 2025–2026

| Recipient | Individual Limit | Note |
|-----------|------------------|------|
| Candidate committee | **$3,500 per election** | Primary and general are **separate elections** = separate limits |
| PAC (SSF/nonconnected) | $5,000 per year | |
| Party (state/district/local) | $10,000 per year combined | |
| Party (national) | $44,300 per year | |

**Per candidate, per cycle:** Up to $3,500 (primary) + $3,500 (general) = **$7,000** if candidate runs in both.

**Candidates who lose primary:** No separate general limit. General-designated contributions must be refunded/redesignated within 60 days.

**Indexed for inflation** in odd-numbered years.

### North Carolina State (NCSBE)

| Recipient | Individual Limit | Note |
|-----------|------------------|------|
| Candidate / political committee | **$6,800 per election** (2025) | Primary and general are **separate elections** = separate limits |
| | $6,400 (2024) | CPI-adjusted each odd year |

**Per candidate, per cycle:** Up to $6,800 (primary) + $6,800 (general) = **$13,600** if candidate runs in both.

**Source:** NCSBE, G.S. 163-278.13. Limit CPI-adjusted at start of each odd-numbered year.

**Local/municipal:** May differ; verify per jurisdiction.

---

## Rule 3: Election Cycle & Type in Schema

Any donor aggregation or limit tracking must distinguish:

- `election_cycle` (e.g., 2024, 2026)
- `election_type` (primary, general, runoff, special)
- `race_level` (federal, state, local, municipal, county)
- `office_type` (US House, NC Senate, Sheriff, School Board, etc.)

Limits apply **per election** (primary ≠ general). Aggregating across cycle without election_type can misstate compliance.

---

## References

- FEC Contribution Limits: https://www.fec.gov/help-candidates-and-committees/candidate-taking-receipts/contribution-limits/
- NC campaign finance: NCSBE (ncsbe.gov), G.S. 163-278.13, CPI-adjusted each odd year
- Schema: `contribution_limits` (ecosystem_02), `e02_contribution_limits` (Perplexity)
