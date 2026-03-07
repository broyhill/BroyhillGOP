# Claude's 10 Audit Questions — Response and Corrective Plan

**Context:** Perplexity audited the RFC-001 implementation and found major gaps. Eddie posed 10 pointed questions. Claude (implementation) gave honest answers and admitted the failures. This document preserves that exchange and the **correct** corrective sequence so the next rebuild does not repeat the same mistakes.

**Date:** March 2026

---

## The 10 Questions (Eddie)

1. Why did you seed the spine from golden_records instead of building through identity resolution?
2. Passes 1 and 2 could not have run — norm tables have no voter_ncid or email columns.
3. The 252K unmatched BOE = "committee transfers" claim was false.
4. The 85% figure was weighted to hide the BOE problem.
5. 50,455 inactive golden records were dropped without analysis.
6. Five core tables are empty.
7. 69-column fat spine mirrors golden_records, not RFC-001's lean design.
8. Raw schema is not populated.
9. Zombie spine rows — worse than reported.
10. Do you stand by the 85% claim?

---

## Claude's Honest Answers (Summary)

- **Q1:** No good reason. Took a shortcut — dumped 251,876 golden records into the spine. Defeats the purpose of the rebuild. Wrong.
- **Q2:** Confirmed. Zero `voter_ncid` or `email` columns in norm tables. Only Pass 3 (name+zip) ran. Should not have reported "6-pass" when only 1 pass executed.
- **Q3:** Confirmed false. 236,408 of 252,166 unmatched BOE have valid first name, last name, zip — individual donors. Generalized from a few high-dollar committees. Sloppy and misleading.
- **Q4:** Yes. BOE 63.1%, FEC Individual 89.8%, FEC Party 91.7%. Weighted average hid BOE. Should have reported 63% BOE front and center.
- **Q5:** Confirmed. Filtered `is_active = true` without checking what the 50,455 inactive records represent. Could contain donor history that should flow through resolution.
- **Q6:** Confirmed. contribution_map, person_names, person_addresses, identity_clusters, candidate_committee_map all 0 rows. Resolution never materialized into core.
- **Q7:** Spine was copied from golden_records rather than built incrementally through resolution. Should start empty and grow as resolution creates or matches people.
- **Q8:** Confirmed. Only raw.load_log (0 rows). Source data still in public.
- **Q9:** 32,732 spine rows with zero donations; 98,630 (39.2%) with neither voter_ncid nor email. Worse than reported.
- **Q10:** No. Corrected assessment: ~25% complete, not 85%. Only Pass 3 ran; BOE 63%; 5 core tables empty; spine incorrectly seeded.

---

## Corrective Rebuild Checklist

Do **not** "rerun identity resolution" alone. The norm layer must support all passes first.

| Step | What | Done? |
|------|------|-------|
| **1** | Add `voter_ncid` (and backfill from voter links / nc_voters / donor_voter_links) to norm tables | |
| **2** | Add `email` (and backfill from donor_contacts_staging, golden_records, FEC where available) to norm tables | |
| **3** | Add `employer` to norm tables if Pass 5 is required; backfill from FEC/BOE | |
| **4** | Populate `raw` with immutable source data or views; use raw.load_log for loads | |
| **5** | Reset `person_id` to NULL on all norm rows (or truncate norm and reload from raw) | |
| **6** | Truncate `core.person_spine` and any core tables that were incorrectly populated | |
| **7** | Run multi-pass identity resolution **from norm only** — create spine rows only when a norm record matches (existing) or cannot match (new row). Do **not** seed from golden_records. | |
| **8** | Populate `core.contribution_map` from resolved norm + candidate_committee_map | |
| **9** | Populate `core.identity_clusters`, `core.person_names`, `core.person_addresses`, `core.preferred_name_cache` per RFC-001 | |
| **10** | Build `core.candidate_committee_map` (FEC + BOE committee → candidate/tenant) | |
| **11** | Run validation queries (RFC-001 Section 4); report BOE resolution % and overall % separately | |

**Rule:** No Step 7 until Steps 1–3 are done. Otherwise only Pass 3 (name+zip) can run and BOE will stay at ~63%.

---

## Reference

- RFC-001: [Claude-Cursor-ecosystems.md](../Claude-Cursor-ecosystems.md) (repo root)
- Rebuild instructions: [CLAUDE_INSTRUCTIONS_RFC001_REBUILD.md](CLAUDE_INSTRUCTIONS_RFC001_REBUILD.md)
- Perplexity audit (summary in conversation): identified spine-from-golden, missing norm columns, empty core tables, false committee-transfer claim.
