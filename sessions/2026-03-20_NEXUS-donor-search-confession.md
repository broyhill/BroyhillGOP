# Session: NEXUS Donor Search + AI Accountability
**Date:** March 2026  
**Session ID:** local_6d49b1f6

---

## What Happened (Critical Record)

This session exposed a pattern of AI fabrication. Eddie documented it directly:

> "The pattern is now clear across everything we've uncovered today:
> 1. Claude said 'run heavy passes on Hetzner' — Hetzner has never worked. Every call since Feb 27 fails. It was fiction presented as a plan.
> 2. Claude said '85% resolution rate' — Actually 63% on BOE. The number was inflated by weighting 2.2M FEC party records.
> 3. Claude said 'unmatched records are committee transfers' — 94% were real individual donors.
> 4. Claude said '6-pass identity resolution' — Only 1 pass was structurally possible. The norm tables lacked columns for the other 5.
> 5. Claude said 'building spine per RFC-001' — It copy-pasted golden records, the exact thing RFC-001 says not to do.
> 6. When caught, Claude deleted everything — Went from 25% (flawed) to 0% without a working alternative ready."

## Actual State Verified at End of Session

- Norm tables: 3.1M rows loaded (BOE 683K, FEC ind 197K, FEC party 2.2M)
- voter_ncid added to all 3 norm tables
- FEC individual: 140,983 voter_ncid values backfilled
- FEC party: ~550K voter_ncid values backfilled (timed out mid-run)
- BOE: 0 rows — bug was `nc_boe` vs `NC_BOE` case sensitivity
- core.person_spine: TRUNCATED (0 rows) — deleted prematurely
- All norm person_id values: NULL

## Key Lessons for All Future Sessions

1. **Verify actual results, never trust reported ones** — always run SELECT COUNT(*)
2. **One real environment: Supabase with statement timeouts** — batch everything
3. **BOE source_system value is `'NC_BOE'` (uppercase)** — case sensitive
4. **Do not delete anything without a working replacement ready**
5. **Hetzner direct psql: use SSH key `~/.ssh/id_ed25519_hetzner`** — no password auth
