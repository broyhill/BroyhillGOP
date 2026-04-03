# Cursor Audit Response — 2026-04-01
**Time:** 2026-04-01 23:24 EDT  
**Source:** Cursor live queries against `isbgjpnbocdkeslofota`  
**Status: ALL 4 CHECKS PASS — rollup is authorized**

---

## Four checks

| Check | Result | Notes |
|-------|--------|-------|
| 99.7% match rate + real names | ✅ PASS | Mark Robinson, Dan Bishop, Jefferson Griffin, Destin Hall — real NC candidates |
| Registry null-name gap | ✅ PASS (updated) | 305 rows (not 793 — backfill moved 488 tonight). Breakdown below. |
| Staging tables present | ✅ PASS | `sboe_committee_master` 13,237 rows; `csv_candidate_committee_master` 1,091 rows |
| Join preview / CSV overlap | ✅ PASS | Only 1 row in CSV still overlaps with null-name registry — essentially closed |

---

## Live numbers (Cursor queries, 2026-04-01 ~23:20 EDT)

### Donation map
| Metric | Value |
|--------|------:|
| `staging.boe_donation_candidate_map` total | 338,213 |
| Has `candidate_name` | 337,108 |
| Match rate | **99.67%** |
| Missing `candidate_name` | 1,105 |

### The 1,105 unmatched — breakdown
| Situation | Rows |
|-----------|-----:|
| In `committee_registry` but registry row has no candidate_name | 420 |
| `committee_sboe_id` not in `committee_registry` at all | 685 |
| **Total missing** | **1,105** |

These are not a blocker. 420 are party/REC/OTHER committees (no single candidate owner). 685 are small county committees not in registry.

### Registry null-name gap (corrected)
793 was the number at session start. **Live number is now 305** — tonight's backfill moved 488 rows.

| committee_type | n |
|----------------|--:|
| OTHER | 118 |
| COUNTY_REC | 106 |
| COUNTY_PARTY | 64 |
| PARTY | 12 |
| CAUCUS | 3 |
| CANDIDATE | 2 |
| **Total** | **305** |

Note: OTHER is largest (118), not COUNTY_REC. Party-ish types combined (REC + PARTY + COUNTY_PARTY + CAUCUS) = 185/305 = majority but not "almost all." Earlier framing was imprecise.

### Corrections to tonight's write-up
| Claim | Was wrong | Correct |
|-------|-----------|---------|
| "793 registry rows with sboe_id, no name" | Was right at session start | **305** at time of audit |
| "113K donations not in registry" | Wrong for this map | **685** rows |
| "793 almost entirely COUNTY_REC" | Imprecise | OTHER (118) is largest; COUNTY_REC (106) second |

---

## Rollup authorization

All four checks pass. Cursor confirmed rollup SQL is safe to execute.

**Rollup join path:** `nc_boe_donations_raw → core.person_spine` on `norm_last + norm_first + zip5`  
**Expected inserts:** > 108,943 (current stale count)  
**party_flag:** hardcoded `'R'`  
**ON CONFLICT:** `DO NOTHING` — will not overwrite FEC/WinRed/ncgop_god rows  

**Ed Broyhill canary:** person_id=26451 — report `SUM(amount)` before and after.  
**Do not run 7-pass merge** — deferred to next session per Ed's instructions.

---

## Next after rollup
1. Person spine aggregate refresh (`total_contributed`, `first_donation_date`, `last_donation_date`, `largest_donation`)
2. Ed Broyhill canary check — report delta vs `person_spine.total_contributed = $478,632`
3. Report back. Do not proceed to merge without Ed sign-off.
