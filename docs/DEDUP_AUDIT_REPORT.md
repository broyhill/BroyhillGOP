# AUDIT: ncboe_internal_dedup.py vs DONOR_DEDUP_PIPELINE_V2.md

**Auditor:** Perplexity Computer
**Date:** April 12, 2026 10:50 PM EDT
**Subject:** Line-by-line audit of Cursor's Stage 1 implementation
**Verdict:** DO NOT RUN — critical gaps in 1D–1G, double-commit bug, memory bomb

---

## EXECUTIVE SUMMARY

Cursor implemented 1A, 1B, and 1C (partially). Stages 1D, 1E, 1F, and 1G are **not implemented as clustering stages** — they are only partially represented in the cluster_profile builder at the end. The script will produce clusters that are too fragmented (under-merged) because it never uses address numbers, name variants, employer history, or multi-address data as clustering signals. It only collects them post-hoc for the profile JSON.

The `db.py` double-commit bug will fire on every run. The `fetchall()` on 2.4M rows will consume ~4-6 GB RAM minimum.

---

## STAGE-BY-STAGE AUDIT

### Stage 1A — Exact match clustering ✅ IMPLEMENTED (with caveat)

**V2 spec:** Group by exact last name + exact first name + exact zip5
**Code (lines 90-94):**
```python
if last and first and z5:
    k = (last, first, z5)
    if k not in root_1a:
        root_1a[k] = rid
    uf.union(rid, root_1a[k])
```

**Verdict:** Correctly implemented. Uses `norm_last`, `norm_first`, `norm_zip5`. The reverse-chronological ORDER BY (line 58) means the first row seen for each key is the most recent, which is correct per V2's "process 2026→2015" rule.

**Minor caveat:** Uses normalized names (lowered/stripped), not exact raw names. This is actually better than the spec's "exact" wording — it catches "Ed Broyhill" vs "ED BROYHILL". Acceptable.

---

### Stage 1B — Employer cluster ✅ IMPLEMENTED (with caveat)

**V2 spec:** Group by last name + normalized employer + city
**Code (lines 95-99):**
```python
if last and emp and cit:
    k2 = (last, emp, cit)
    if k2 not in root_1b:
        root_1b[k2] = rid
    uf.union(rid, root_1b[k2])
```

**Verdict:** Correctly implemented. Uses `norm_employer` and `norm_city` which should already have SIC normalization applied from the normalize phase.

**Caveat:** The V2 spec says to use `employer_sic_master` (62,100 mappings) for normalization. This code relies on `norm_employer` already being normalized in the `raw.ncboe_donations` table. Need to verify that the Phase 2 normalizer actually did SIC-based employer normalization into `norm_employer`, or if it just did basic string cleaning. If only string cleaning, then "ANVIL VENTURE GROUP" and "ANVIL VENTURES" and "ANVIL MANAGEMENT LLC" would NOT cluster together — defeating the purpose of 1B.

**ACTION NEEDED:** Check what `phase2_normalize.py` actually did to `norm_employer`. If it's just lowercase/strip, 1B is effectively broken for its intended purpose.

---

### Stage 1C — Committee loyalty fingerprint ⚠️ PARTIALLY IMPLEMENTED

**V2 spec:** Group by last name + zip5 + committee_id **pattern** — if same person gives to same 3+ committees across multiple years, that's one person.

**Code (lines 101-117):**
```python
triple_counts: defaultdict[tuple[str, str, str], int] = defaultdict(int)
triple_ids: defaultdict[tuple[str, str, str], list[int]] = defaultdict(list)
for tup in rows:
    rid = tup[0]
    last, z5, cm = (tup[1] or ""), (tup[3] or ""), (tup[6] or "")
    if last and z5 and cm:
        t = (last, z5, cm)
        triple_counts[t] += 1
        triple_ids[t].append(rid)

for t, cnt in triple_counts.items():
    if cnt < min_committee_repeat:
        continue
    ids = triple_ids[t]
    root = min(ids)
    for i in ids:
        uf.union(i, root)
```

**What's wrong:**

1. **Counts individual (last, zip, committee) triples, not committee PATTERNS.** The V2 spec says: "if BILL SMITH at 27104 gives to the **same 3+ committees** across multiple years." This means you look at the SET of committees a person gives to. Cursor's code counts how many times the triple (last, zip, committee) appears — so if BILL SMITH gives to Committee X five times, that triple has count=5 and passes the threshold. That's just "repeated giving to one committee," not a committee fingerprint.

2. **The V2 intent is a SET-based fingerprint:** Collect {committee_A, committee_B, committee_C} for (SMITH, 27104). If another row also has SMITH + 27104 + committee_A, they share a fingerprint element. The power is that no two people with the same name in the same zip give to the EXACT same set of 3+ committees. Cursor's code doesn't build this set comparison at all.

3. **Still unions rows together, but on a weaker signal than intended.** It will correctly merge rows where the same (last, zip, committee) appears 3+ times, but it misses the cross-committee identity fingerprint that is the actual purpose of 1C.

**Impact:** Moderate. The code will still merge some rows (anyone who gives to the same committee 3+ times with same name+zip), but it's a weaker clustering signal than the V2 design intended.

---

### Stage 1D — Address number collection ❌ NOT IMPLEMENTED AS CLUSTERING

**V2 spec:** "For each cluster, collect ALL address numbers from BOTH Street Line 1 AND Street Line 2 across all transactions."

**What Cursor did:** The code reads `address_numbers` and `all_addresses` from the database (line 53-55) and stuffs them into the cluster_profile JSON (lines 183-188), but **never uses address numbers as a clustering signal.**

**What's missing:** Stage 1D is described in V2 as a COLLECTION stage that feeds Stage 2 (voter file matching). But the collection should happen during clustering so that when two rows are merged by 1A/1B/1C, their combined address numbers are available. Cursor does this in the profile builder — so the collection happens, but only after clustering is finished.

**The real problem:** Address numbers could also be used as an additional union signal. If ROW_A (SMITH, 27104, address_num=525) and ROW_B (SMITH, 27104, address_num=525) share the same address number + last name + zip, they should be merged even if first names differ. This cross-linkage is never attempted.

**Verdict:** The post-hoc collection in lines 183-185 is correct but insufficient. No clustering use of address numbers.

---

### Stage 1E — Name variant collection ❌ NOT IMPLEMENTED AS CLUSTERING

**V2 spec:** "For each cluster, collect ALL first name variants used across all transactions. Do NOT use nickname lookup tables."

**What Cursor did:** Collects `norm_first` into `name_variants_first` in the profile (line 176), but **never uses name variants to merge clusters.**

**What's missing:** The V2 example: "POPE + VARIETY WHOLESALERS + RALEIGH → {ART, ARTHUR, JAMES, JAMES A., JAMES ARTHUR, JAMES ART}" — this means once a cluster is formed by 1A/1B, you should check if other unclustered rows share any name variant with an existing cluster (same last name + zip or same employer + city). This iterative refinement is completely absent.

**Impact:** Major. A donor who files as "ED BROYHILL" in 2020 and "EDGAR BROYHILL" in 2016 with the same zip will NOT be merged by 1A (different first names). They might be merged by 1B if they have the same employer+city, but if the employer changed or one says RETIRED, they stay fragmented. Name variant merging across clusters would catch this.

---

### Stage 1F — Employer history collection ❌ NOT IMPLEMENTED AS CLUSTERING

**V2 spec:** "For each cluster, collect ALL employers across all 11 years. This solves the RETIRED problem."

**What Cursor did:** Collects employers into the profile (lines 189-190), but **never uses employer history to bridge clusters.**

**What's missing:** The V2 example: 2016 CEO/ANVIL VENTURES → 2024 RETIRED/RETIRED. If these are different first-name variants (ED vs EDGAR), they won't merge by 1A or 1B. The V2 vision is that once you know ED BROYHILL worked at ANVIL VENTURES, and you see EDGAR BROYHILL / RETIRED in the same zip, you can bridge them using the employer history from the cluster. This requires a second pass or iterative merging — completely absent.

**Impact:** Critical for major donors who are now RETIRED. The script will fragment their donation history.

---

### Stage 1G — Multi-address / Second home collection ❌ NOT IMPLEMENTED AS CLUSTERING

**V2 spec:** "For each cluster, collect ALL complete addresses... Donors may file from primary home, business/office, second home (beach, mountains, lake houses), Florida second home, PO Boxes, vacation properties."

**What Cursor did:** Collects addresses into the profile (lines 186-188), but **never uses multi-address information to merge clusters.**

**What's missing:** If ED BROYHILL files from 27104 (Winston-Salem) in 2016 and from 28480 (Wrightsville Beach) in 2024, 1A won't merge them (different zip). 1B might if same employer+city, but if one says "RETIRED" and the city changed, they stay separate. V2 envisions that multi-address collection enables cross-zip merging — "if this cluster already includes a 27104 address and this new row has the same name + 27104, absorb it even though the new row's primary zip is 28480."

**Impact:** Critical for wealthy donors with multiple properties — exactly the high-value targets Ed cares most about.

---

## BUG: DOUBLE-COMMIT

### db.py (lines 84-106):
```python
@contextmanager
def get_connection():
    p = init_pool()
    conn = None
    try:
        conn = p.getconn()
        yield conn
    except Exception as e:
        if conn is not None:
            conn.rollback()
        raise
    finally:
        if conn is not None:
            conn.commit()        # ← COMMIT #1: always fires on context exit
            p.putconn(conn)
```

### ncboe_internal_dedup.py (line 215):
```python
    conn.commit()                # ← COMMIT #2: explicit in run_stage1()
```

### main() (lines 225-226):
```python
    with get_connection() as conn:
        info = run_stage1(conn, min_committee_repeat=args.min_committee_repeat)
    # ← context manager exits here, fires COMMIT #1 again
```

**Flow:**
1. `run_stage1()` does a massive UPDATE loop (lines 173-214)
2. Line 215: `conn.commit()` — COMMIT #2 fires, writes all cluster_id/cluster_profile updates
3. Function returns, `with get_connection()` block exits
4. `finally` in `get_connection()` calls `conn.commit()` — COMMIT #1 fires (no-op since nothing new)

**Actual risk:** In the happy path, the double-commit is harmless — the second commit is a no-op. **BUT if an exception occurs between line 215 and the context exit, the `finally` block calls `conn.commit()` AFTER the rollback in the `except` block never fires** because `run_stage1` already committed. Partial state is permanently written.

**Worse scenario:** If the UPDATE loop at lines 173-214 fails mid-way (say at cluster 50,000 of 107,000), the explicit `conn.commit()` on line 215 never fires. Good — nothing committed. But then the exception propagates to `get_connection()`, which calls `conn.rollback()` in the `except` block. So far so good. **BUT** — look at the `finally` block: it calls `conn.commit()` AFTER the rollback. Wait, no — re-reading the code: the `except` block raises, and the `finally` block runs after that. The `finally` calls `conn.commit()`. But there's nothing to commit because the rollback already cleared the transaction. So it's actually safe in this specific flow.

**The REAL bug is more subtle:** The `finally` block always calls `conn.commit()`. If some other code path adds writes to the connection after `run_stage1()` returns but before the `with` block exits, those writes get silently committed without explicit intent. This is a design smell, not a data-loss bug for this specific script. But it's a landmine for any future code that reuses the connection.

**RECOMMENDATION:** Remove the `conn.commit()` from `db.py` line 105. The caller should always explicitly commit. Automatic commits on context exit violate the principle of least surprise.

---

## BUG: MEMORY BOMB

### ncboe_internal_dedup.py (lines 51-61):
```python
    cur.execute("""
        SELECT id, norm_last, norm_first, norm_zip5, norm_employer, norm_city,
               committee_sboe_id, year_donated, address_numbers, all_addresses,
               name, employer_name, street_line_1, street_line_2, city, zip_code,
               norm_amount, transction_type
        FROM raw.ncboe_donations
        ORDER BY year_donated DESC NULLS LAST, id ASC
    """)
    rows = cur.fetchall()
```

**Problem:** Loads ALL 2,431,198 rows × 18 columns into Python memory as a list of tuples. Each row is roughly 500-2000 bytes depending on string lengths. Estimated memory: **2-5 GB** for the raw tuples alone.

Then the code iterates over `rows` THREE separate times (lines 66, 103, 121) plus builds the `clusters` dict (line 129) which duplicates most of the data. Peak memory usage: **4-8 GB**.

The Hetzner server has sufficient RAM, but this is fragile. A proper implementation would use server-side cursors or process in chunks.

**RECOMMENDATION:** Use `cur.itersize = 10000` with a named cursor, or process via SQL-based clustering instead of Python-side.

---

## CLUSTER PROFILE AUDIT

### V2 Required Output vs What Cursor Builds:

| V2 Required Field | Cursor Profile Key | Status |
|---|---|---|
| All name variants (first names) | `name_variants_first` | ✅ Present |
| All address numbers | `address_numbers` | ✅ Present |
| All complete addresses | `addresses` | ✅ Present |
| All employers (across 11 years) | `employers` | ✅ Present |
| All cities | `cities` | ✅ Present |
| All zip codes | `zip5s` | ✅ Present |
| Committee fingerprint | `committees` | ✅ Present |
| Total transactions | `n_rows` | ✅ Present (as row count) |
| Total dollars | `total_amount` | ✅ Present |
| First and last donation dates | — | ❌ MISSING |
| Donation year range | — | ❌ MISSING |

**Missing from profile:**
- `first_donation_date` / `last_donation_date` — not collected despite `year_donated` being in the SELECT
- `year_range` (min_year – max_year) — trivial to add from `year_donated`

---

## ADDITIONAL ISSUES

### 1. Blanket NULL reset (line 174)
```python
cur.execute("UPDATE raw.ncboe_donations SET cluster_id = NULL, cluster_profile = NULL")
```
This NULLs out cluster_id and cluster_profile for ALL 2.4M rows before writing new values. If the script crashes mid-update, you lose all previous clustering work with no way to recover. Should be wrapped in a transaction with the updates, or better yet, use a separate staging table.

### 2. No dry-run mode
The script has no way to preview results before committing. For a dataset this critical, there should be a `--dry-run` flag that reports cluster counts without writing.

### 3. No logging of cluster statistics
No output of: how many clusters formed, size distribution, largest clusters (sanity check), singleton count. The return dict has `clusters` and `rows` but no distribution data.

### 4. Row iteration is O(n) × 3
The code iterates all 2.4M rows three times (1A/1B pass, 1C pass, profile-building pass). Could be consolidated to two passes (clustering + profile building).

### 5. No pre-validation
Does not check that `norm_*` columns are populated before running. If Phase 2 normalization hadn't run, the script would create garbage clusters based on NULLs.

---

## SUMMARY SCORECARD

| Stage | V2 Spec | Cursor Implementation | Gap |
|---|---|---|---|
| 1A | Exact name+zip cluster | ✅ Correct | None |
| 1B | Employer+city cluster | ✅ Correct (if norm_employer uses SIC) | Verify SIC normalization |
| 1C | Committee fingerprint | ⚠️ Wrong signal (count per triple, not set pattern) | Moderate |
| 1D | Address number collection for clustering | ❌ Collection only, no clustering use | High |
| 1E | Name variant cross-cluster merging | ❌ Collection only, no merging | Critical |
| 1F | Employer history cross-cluster bridging | ❌ Collection only, no bridging | Critical |
| 1G | Multi-address cross-zip merging | ❌ Collection only, no merging | Critical |
| Profile | All required fields | ⚠️ Missing date range fields | Low |
| Bug | Double-commit | ⚠️ Mostly harmless but design smell | Fix before production |
| Bug | Memory bomb | ⚠️ 4-8 GB peak, fragile | Redesign for safety |
| Bug | Blanket NULL reset | ❌ Destroys data on crash | High risk |

---

## VERDICT

**DO NOT RUN THIS SCRIPT.** It will produce clusters that are too fragmented — under-merged by a significant margin. The core V2 innovation (stages 1D-1G using collected data to iteratively merge clusters across name variants, addresses, and employers) is completely missing. What Cursor built is a basic 3-rule union-find with a post-hoc profile builder. That's about 40% of what V2 specifies.

### What needs to happen:
1. Fix 1C to use set-based committee fingerprinting
2. Implement 1D-1G as iterative merge passes AFTER the initial 1A/1B/1C clustering
3. Add first/last donation date to profile
4. Remove blanket NULL reset, use transactional staging
5. Remove `conn.commit()` from `db.py` line 105
6. Add `--dry-run` mode
7. Add pre-validation that norm_* columns are non-null
8. Add cluster statistics logging

---

*This audit was performed by reading every line of ncboe_internal_dedup.py (233 lines) against the 277-line DONOR_DEDUP_PIPELINE_V2.md specification.*
