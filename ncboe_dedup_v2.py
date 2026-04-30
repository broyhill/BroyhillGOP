#!/usr/bin/env python3
"""
NCBOE Internal Dedup — V2 Complete Implementation
Stages 1A through 1G per DONOR_DEDUP_PIPELINE_V2.md

After clustering, propagates rnc_regid from matched rows to unmatched
cluster members — resolving dark donors via identity linkage.

Usage:
  python3 ncboe_dedup_v2.py              # dry-run (no writes)
  python3 ncboe_dedup_v2.py --apply      # write clusters to DB
  python3 ncboe_dedup_v2.py --apply --propagate-ids  # clusters + rnc_regid propagation
"""

import argparse
import json
import logging
import sys
import time
from collections import defaultdict

import psycopg2

DB_URL = "postgresql://postgres:${PG_PASSWORD_URLENCODED}@127.0.0.1:5432/postgres"
LOG_FILE = "/tmp/ncboe_dedup_v2.log"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(message)s",
    handlers=[
        logging.FileHandler(LOG_FILE, mode="w"),
        logging.StreamHandler(sys.stdout),
    ],
)
log = logging.getLogger("dedup_v2")


# ── Union-Find with path compression and union-by-min ──

class UnionFind:
    __slots__ = ("_p",)

    def __init__(self):
        self._p: dict[int, int] = {}

    def find(self, x: int) -> int:
        if x not in self._p:
            self._p[x] = x
        r = x
        while self._p[r] != r:
            r = self._p[r]
        # path compression
        while self._p[x] != r:
            self._p[x], x = r, self._p[x]
        return r

    def union(self, a: int, b: int) -> bool:
        """Union by min-id. Returns True if a merge actually happened."""
        ra, rb = self.find(a), self.find(b)
        if ra == rb:
            return False
        if ra < rb:
            self._p[rb] = ra
        else:
            self._p[ra] = rb
        return True

    def components(self, ids):
        """Return {root: [member_ids]} for the given id set."""
        comps = defaultdict(list)
        for i in ids:
            comps[self.find(i)].append(i)
        return dict(comps)


# ── Data loading ──

def load_rows(conn):
    """Load all donation rows. Returns list of dicts keyed by id."""
    log.info("Loading rows from raw.ncboe_donations...")
    t0 = time.time()
    with conn.cursor() as cur:
        cur.execute("""
            SELECT id, norm_last, norm_first, norm_middle, norm_zip5,
                   norm_employer, norm_city, committee_sboe_id,
                   year_donated, address_numbers, all_addresses,
                   name, employer_name, street_line_1, street_line_2,
                   city, zip_code, norm_amount, transction_type,
                   rnc_regid, state_voter_id, dt_first, dt_middle,
                   dt_suffix, dt_prefix, dt_zip4, dt_house_hold_id
            FROM raw.ncboe_donations
            ORDER BY year_donated DESC NULLS LAST, id ASC
        """)
        cols = [d[0] for d in cur.description]
        rows_raw = cur.fetchall()

    rows = []
    by_id = {}
    for r in rows_raw:
        d = dict(zip(cols, r))
        rows.append(d)
        by_id[d["id"]] = d

    log.info(f"  Loaded {len(rows):,} rows in {time.time()-t0:.1f}s")
    return rows, by_id


# ── Pre-validation ──

def validate(rows):
    n_total = len(rows)
    n_norm = sum(1 for r in rows if r["norm_last"])
    n_null = n_total - n_norm
    log.info(f"  Pre-validation: {n_total:,} total, {n_norm:,} with norm_last, {n_null:,} without")
    if n_norm < n_total * 0.9:
        log.error("ABORT: Less than 90% of rows have norm_last — normalization may not have run")
        return False
    return True


# ── Stage 1A: Exact (last, first, zip5) ──

def stage_1a(rows, uf):
    log.info("Stage 1A: Exact last+first+zip5...")
    t0 = time.time()
    roots = {}
    merges = 0
    for r in rows:
        rid = r["id"]
        uf.find(rid)
        last, first, z5 = r["norm_last"] or "", r["norm_first"] or "", r["norm_zip5"] or ""
        if last and first and z5:
            k = (last, first, z5)
            if k in roots:
                if uf.union(rid, roots[k]):
                    merges += 1
            else:
                roots[k] = rid
    log.info(f"  1A: {merges:,} merges in {time.time()-t0:.1f}s")
    return merges


# ── Stage 1B: Employer cluster (last, employer, city) ──

GENERIC_EMPLOYERS_1B = {
    "RETIRED", "SELF", "SELF-EMPLOYED", "SELF EMPLOYED", "NOT EMPLOYED",
    "NONE", "N/A", "NA", "HOMEMAKER", "STUDENT", "UNEMPLOYED",
    "NO EMPLOYER", "INFORMATION REQUESTED", "INFORMATION REQUESTED PER BEST EFFORTS",
    "",
}


def stage_1b(rows, uf):
    log.info("Stage 1B: Employer last+employer+city (skip generic employers)...")
    t0 = time.time()
    roots = {}
    merges = 0
    skipped = 0
    for r in rows:
        rid = r["id"]
        last = r["norm_last"] or ""
        emp = (r["norm_employer"] or "").strip()
        cit = r["norm_city"] or ""
        if not (last and emp and cit):
            continue
        if emp in GENERIC_EMPLOYERS_1B:
            skipped += 1
            continue
        k = (last, emp, cit)
        if k in roots:
            if uf.union(rid, roots[k]):
                merges += 1
        else:
            roots[k] = rid
    log.info(f"  1B: {merges:,} merges, {skipped:,} skipped (generic employer) in {time.time()-t0:.1f}s")
    return merges


# ── Stage 1C: Committee fingerprint (set-based) ──

def stage_1c(rows, uf, min_shared=3):
    log.info(f"Stage 1C: Committee set fingerprint (min_shared={min_shared})...")
    t0 = time.time()

    # Build committee sets per (last, zip5)
    person_committees = defaultdict(lambda: defaultdict(set))  # (last,zip) -> {first -> {committees}}
    person_ids = defaultdict(lambda: defaultdict(list))         # (last,zip) -> {first -> [ids]}

    for r in rows:
        last, z5, cm = r["norm_last"] or "", r["norm_zip5"] or "", r["committee_sboe_id"] or ""
        first = r["norm_first"] or ""
        if last and z5 and cm and first:
            key = (last, z5)
            person_committees[key][first].add(cm)
            person_ids[key][first].append(r["id"])

    # Build cluster-level rnc_regid sets (considers ALL rows in cluster, not just one first name)
    cluster_regids = defaultdict(set)  # root -> {rnc_regids}
    for r in rows:
        regid = r.get("rnc_regid") or ""
        if regid:
            root = uf.find(r["id"])
            cluster_regids[root].add(regid)

    # For each (last, zip), find pairs of different first names with >= min_shared committees
    merges = 0
    blocked = 0
    for key, first_map in person_committees.items():
        firsts = list(first_map.keys())
        if len(firsts) < 2:
            continue
        for i in range(len(firsts)):
            for j in range(i + 1, len(firsts)):
                shared = first_map[firsts[i]] & first_map[firsts[j]]
                if len(shared) >= min_shared:
                    # Guard: check CLUSTER-level rnc_regids, not just per-name
                    # This catches cases where ED has no regid but ED's cluster
                    # (via EDGAR/JAMES) has c45eeea9, while MELANIE has 8d88ee52
                    ids_i = person_ids[key][firsts[i]]
                    ids_j = person_ids[key][firsts[j]]
                    root_i = uf.find(ids_i[0])
                    root_j = uf.find(ids_j[0])
                    if root_i == root_j:
                        continue  # already merged
                    ri = cluster_regids.get(root_i, set())
                    rj = cluster_regids.get(root_j, set())
                    if ri and rj and not (ri & rj):
                        blocked += 1
                        continue
                    # These two name variants give to 3+ of the same committees — same person
                    anchor = min(ids_i[0], ids_j[0])
                    for rid in ids_i + ids_j:
                        if uf.union(rid, anchor):
                            merges += 1
                    # Update cluster regids after merge
                    new_root = uf.find(anchor)
                    cluster_regids[new_root] = ri | rj

    log.info(f"  1C: {merges:,} merges, {blocked:,} blocked (regid conflict) in {time.time()-t0:.1f}s")
    return merges


# ── Stage 1D: Address number cross-name merge (with first-name guard) ──

def _first_names_compatible(a: str, b: str) -> bool:
    """True if two first names could plausibly be the same person.
    Catches: ED/EDGAR, J/JAMES, BILL/WILLIAM prefix, initial match.
    Blocks: ED/LOUISE, JAMES/MELANIE (clearly different people)."""
    if not a or not b:
        return True  # missing name = can't rule it out
    if a == b:
        return True
    # Initial match: single letter matches first letter of other
    if len(a) == 1 and b.startswith(a):
        return True
    if len(b) == 1 and a.startswith(b):
        return True
    # Prefix match (min 2 chars): ED is prefix of EDGAR
    if len(a) >= 2 and len(b) >= 2:
        if a.startswith(b) or b.startswith(a):
            return True
    return False


def stage_1d(rows, uf, by_id):
    """Same last + zip + address number → merge only if first names are compatible.
    This prevents merging spouses (ED+MELANIE) while still catching
    name variants (ED+EDGAR, JAMES+J) at the same address."""
    log.info("Stage 1D: Address number cross-name merge (last+zip+addr_num+first_compat)...")
    t0 = time.time()
    # (last, zip, addr_num) -> list of (rid, first_name, rnc_regid)
    buckets = defaultdict(list)
    for r in rows:
        last, z5 = r["norm_last"] or "", r["norm_zip5"] or ""
        addr_nums = r["address_numbers"] or []
        if not (last and z5 and addr_nums):
            continue
        rid = r["id"]
        first = r["norm_first"] or ""
        regid = r["rnc_regid"] or ""
        for num in addr_nums:
            num_s = str(num).strip()
            if not num_s:
                continue
            k = (last, z5, num_s)
            buckets[k].append((rid, first, regid))

    merges = 0
    blocked = 0
    for k, members in buckets.items():
        if len(members) < 2:
            continue
        anchor_rid, anchor_first, anchor_regid = members[0]
        for rid, first, regid in members[1:]:
            # Already in same cluster?
            if uf.find(rid) == uf.find(anchor_rid):
                continue
            # Guard 1: if both have different rnc_regids, they are confirmed
            # different people — block the merge
            if anchor_regid and regid and anchor_regid != regid:
                blocked += 1
                continue
            # Guard 2: first names must be compatible
            if not _first_names_compatible(anchor_first, first):
                blocked += 1
                continue
            if uf.union(rid, anchor_rid):
                merges += 1
                # Update anchor's regid if we gained one
                if not anchor_regid and regid:
                    anchor_regid = regid

    log.info(f"  1D: {merges:,} merges, {blocked:,} blocked (spouse/family guard) in {time.time()-t0:.1f}s")
    return merges


# ── Stage 1E: Name variant cross-cluster merge ──

def stage_1e(rows, uf, by_id):
    """
    After 1A-1D, collect all first-name variants per cluster.
    Then: if two clusters share last+zip AND one cluster's first-name set
    overlaps with another's, merge them.
    
    This is the iterative pass that catches ED vs EDGAR.
    """
    log.info("Stage 1E: Name variant cross-cluster merge...")
    t0 = time.time()

    # Build cluster -> {first names} and cluster -> (last, zip) mapping
    cluster_firsts = defaultdict(set)     # root -> set of first names
    cluster_last_zip = {}                  # root -> (last, zip) — use most common
    cluster_ids = defaultdict(list)        # root -> [row ids]

    for r in rows:
        rid = r["id"]
        root = uf.find(rid)
        first = r["norm_first"] or ""
        last = r["norm_last"] or ""
        z5 = r["norm_zip5"] or ""
        if first:
            cluster_firsts[root].add(first)
        if last and z5:
            cluster_last_zip[root] = (last, z5)
        cluster_ids[root].append(rid)

    # Group clusters by (last, zip)
    lz_clusters = defaultdict(list)  # (last,zip) -> [roots]
    for root, lz in cluster_last_zip.items():
        lz_clusters[lz].append(root)

    # For each (last, zip) with multiple clusters, check if any name variants
    # from one cluster appear in another (via DataTrust middle name bridging)
    # Also: if cluster A has first "ED" and cluster B has first "EDGAR",
    # and "ED" is a prefix of "EDGAR" (len >= 2), merge.
    merges = 0
    for lz, roots_list in lz_clusters.items():
        if len(roots_list) < 2:
            continue
        # Try all pairs
        roots_list.sort()
        for i in range(len(roots_list)):
            for j in range(i + 1, len(roots_list)):
                ri, rj = uf.find(roots_list[i]), uf.find(roots_list[j])
                if ri == rj:
                    continue
                fi = cluster_firsts.get(ri, set())
                fj = cluster_firsts.get(rj, set())
                # Direct overlap
                if fi & fj:
                    if uf.union(ri, rj):
                        merges += 1
                        # Merge first-name sets
                        new_root = uf.find(ri)
                        cluster_firsts[new_root] = fi | fj
                    continue
                # Prefix match: "ED" in one set, "EDGAR" in other (or vice versa)
                should_merge = False
                for a in fi:
                    if len(a) < 2:
                        continue
                    for b in fj:
                        if len(b) < 2:
                            continue
                        if a.startswith(b) or b.startswith(a):
                            should_merge = True
                            break
                    if should_merge:
                        break
                if should_merge:
                    if uf.union(ri, rj):
                        merges += 1
                        new_root = uf.find(ri)
                        cluster_firsts[new_root] = fi | fj

    log.info(f"  1E: {merges:,} merges in {time.time()-t0:.1f}s")
    return merges


# ── Stage 1F: Employer history bridge (RETIRED problem) ──

def stage_1f(rows, uf, by_id):
    """
    After clustering, collect all employers per cluster.
    If two clusters share last+zip AND one cluster's employer set overlaps
    with another's (even if one says RETIRED), merge them.
    """
    log.info("Stage 1F: Employer history cross-cluster bridge...")
    t0 = time.time()

    RETIRED_VARIANTS = {"RETIRED", "SELF", "SELF-EMPLOYED", "SELF EMPLOYED",
                        "NOT EMPLOYED", "NONE", "N/A", "NA", "HOMEMAKER",
                        "STUDENT", "UNEMPLOYED", ""}

    cluster_employers = defaultdict(set)
    cluster_last_zip = {}
    
    for r in rows:
        rid = r["id"]
        root = uf.find(rid)
        emp = (r["norm_employer"] or "").strip()
        last = r["norm_last"] or ""
        z5 = r["norm_zip5"] or ""
        if emp and emp not in RETIRED_VARIANTS:
            cluster_employers[root].add(emp)
        if last and z5:
            cluster_last_zip[root] = (last, z5)

    # Group by (last, zip)
    lz_clusters = defaultdict(list)
    for root, lz in cluster_last_zip.items():
        if root in cluster_employers:  # only clusters with real employers
            lz_clusters[lz].append(root)

    merges = 0
    for lz, roots_list in lz_clusters.items():
        if len(roots_list) < 2:
            continue
        roots_list.sort()
        for i in range(len(roots_list)):
            for j in range(i + 1, len(roots_list)):
                ri, rj = uf.find(roots_list[i]), uf.find(roots_list[j])
                if ri == rj:
                    continue
                ei = cluster_employers.get(ri, set())
                ej = cluster_employers.get(rj, set())
                if ei & ej:  # shared employer
                    if uf.union(ri, rj):
                        merges += 1
                        new_root = uf.find(ri)
                        cluster_employers[new_root] = ei | ej

    log.info(f"  1F: {merges:,} merges in {time.time()-t0:.1f}s")
    return merges


# ── Stage 1G: Multi-address / cross-zip merge ──

GENERIC_EMPLOYERS = {
    "RETIRED", "SELF", "SELF-EMPLOYED", "SELF EMPLOYED", "NOT EMPLOYED",
    "NONE", "N/A", "NA", "HOMEMAKER", "STUDENT", "UNEMPLOYED",
    "NO EMPLOYER", "INFORMATION REQUESTED", "INFORMATION REQUESTED PER BEST EFFORTS",
    "",
}


def stage_1g(rows, uf, by_id):
    """
    Cross-zip merge for the SAME person donating from multiple addresses.
    Two approaches:
    
    1) last + real_employer (non-generic) across ANY zip. Drops city constraint
       that 1B uses, so this catches the same person at different locations.
       Guard: first names must be compatible (prefix/initial match).
    
    2) last + first + address_number across different zips.
       Same name + same house number in different zips = likely moved.
    """
    log.info("Stage 1G: Cross-zip merge (last+employer no city, last+first+addr_num)...")
    t0 = time.time()
    merges = 0
    merges_emp = 0
    merges_addr = 0

    # --- Approach 1: last + first + real employer across different zips ---
    # More conservative than dropping city: require first name match too
    # Build: (last, first, employer) -> [(root, zip, rnc_regid)]
    emp_buckets = defaultdict(list)
    seen_row_emp = set()  # dedup
    for r in rows:
        root = uf.find(r["id"])
        last = r["norm_last"] or ""
        first = r["norm_first"] or ""
        emp = (r["norm_employer"] or "").strip()
        z5 = r["norm_zip5"] or ""
        if not (last and first and emp and z5) or emp in GENERIC_EMPLOYERS:
            continue
        k = (last, first, emp)
        dedup_k = (root, k)
        if dedup_k in seen_row_emp:
            continue
        seen_row_emp.add(dedup_k)
        regid = r["rnc_regid"] or ""
        emp_buckets[k].append((root, z5, regid))

    for k, members in emp_buckets.items():
        if len(members) < 2:
            continue
        # Get unique roots with different zips
        unique = []
        seen_r = set()
        zips_seen = set()
        for root, z5, regid in members:
            actual_root = uf.find(root)
            if actual_root not in seen_r:
                seen_r.add(actual_root)
                zips_seen.add(z5)
                unique.append((actual_root, z5, regid))
        if len(unique) < 2 or len(zips_seen) < 2:
            continue
        anchor_root, _, anchor_regid = unique[0]
        for root, _, regid in unique[1:]:
            if uf.find(root) == uf.find(anchor_root):
                continue
            # Guard: different rnc_regids = different people
            if anchor_regid and regid and anchor_regid != regid:
                continue
            if uf.union(anchor_root, root):
                merges += 1
                merges_emp += 1
                anchor_root = uf.find(anchor_root)
                if not anchor_regid and regid:
                    anchor_regid = regid

    # --- Approach 2: last + first + address_number across different zips ---
    addr_buckets = defaultdict(list)  # (last, first, addr_num) -> [(root, zip, regid)]
    for r in rows:
        root = uf.find(r["id"])
        last = r["norm_last"] or ""
        first = r["norm_first"] or ""
        addr_nums = r["address_numbers"] or []
        z5 = r["norm_zip5"] or ""
        regid = r["rnc_regid"] or ""
        if not (last and first and addr_nums):
            continue
        for num in addr_nums:
            num_s = str(num).strip()
            if not num_s:
                continue
            k = (last, first, num_s)
            addr_buckets[k].append((root, z5, regid))

    for k, members in addr_buckets.items():
        # Only interesting if multiple zips
        zips_seen = set()
        unique = []
        seen_r = set()
        for root, z5, regid in members:
            actual_root = uf.find(root)
            if actual_root not in seen_r:
                seen_r.add(actual_root)
                zips_seen.add(z5)
                unique.append((actual_root, z5, regid))
        if len(unique) < 2 or len(zips_seen) < 2:
            continue
        anchor_root, _, anchor_regid = unique[0]
        for root, _, regid in unique[1:]:
            if uf.find(root) == uf.find(anchor_root):
                continue
            if anchor_regid and regid and anchor_regid != regid:
                continue
            if uf.union(anchor_root, root):
                merges += 1
                merges_addr += 1
                anchor_root = uf.find(anchor_root)
                if not anchor_regid and regid:
                    anchor_regid = regid

    log.info(f"  1G: {merges:,} merges ({merges_emp:,} employer, {merges_addr:,} addr) in {time.time()-t0:.1f}s")
    return merges


# ── Build cluster profiles ──

def build_profiles(rows, uf, by_id):
    log.info("Building cluster profiles...")
    t0 = time.time()

    clusters = defaultdict(list)
    for r in rows:
        rid = r["id"]
        root = uf.find(rid)
        clusters[root].append(r)

    profiles = {}
    for cid, members in clusters.items():
        firsts = sorted({m["norm_first"] for m in members if m.get("norm_first")})
        lasts = sorted({m["norm_last"] for m in members if m.get("norm_last")})
        nums = set()
        addrs = set()
        emps = set()
        cities = set()
        zips = set()
        committees = set()
        years = set()
        rnc_ids = set()
        state_ids = set()
        dt_firsts = set()
        dt_middles = set()

        for m in members:
            for n in m.get("address_numbers") or []:
                nums.add(str(n))
            for a in m.get("all_addresses") or []:
                if a:
                    addrs.add(str(a))
            if m.get("norm_employer"):
                emps.add(m["norm_employer"])
            if m.get("norm_city"):
                cities.add(m["norm_city"])
            if m.get("norm_zip5"):
                zips.add(m["norm_zip5"])
            if m.get("committee_sboe_id"):
                committees.add(m["committee_sboe_id"])
            if m.get("year_donated"):
                years.add(m["year_donated"])
            if m.get("rnc_regid"):
                rnc_ids.add(m["rnc_regid"])
            if m.get("state_voter_id"):
                state_ids.add(m["state_voter_id"])
            if m.get("dt_first"):
                dt_firsts.add(m["dt_first"])
            if m.get("dt_middle"):
                dt_middles.add(m["dt_middle"])

        total_amt = sum(float(m["norm_amount"] or 0) for m in members)
        yr_list = sorted(years) if years else []

        profiles[cid] = {
            "cluster_id": cid,
            "n_rows": len(members),
            "name_variants_first": firsts,
            "last_names": lasts,
            "address_numbers": sorted(nums),
            "addresses": sorted(addrs),
            "employers": sorted(emps),
            "cities": sorted(cities),
            "zip5s": sorted(zips),
            "committees": sorted(committees),
            "total_amount": round(total_amt, 2),
            "year_min": yr_list[0] if yr_list else None,
            "year_max": yr_list[-1] if yr_list else None,
            "year_range": yr_list,
            "rnc_regids": sorted(rnc_ids),
            "state_voter_ids": sorted(state_ids),
            "dt_canonical_firsts": sorted(dt_firsts),
            "dt_canonical_middles": sorted(dt_middles),
        }

    log.info(f"  Built {len(profiles):,} cluster profiles in {time.time()-t0:.1f}s")
    return clusters, profiles


# ── Household linkage (post-clustering) ──

def build_household_links(clusters, profiles):
    """Link clusters into households using dt_house_hold_id.
    Does NOT merge clusters — each person stays their own cluster.
    Adds household_id and household_total to each profile."""
    log.info("Building household linkage from dt_house_hold_id...")
    t0 = time.time()

    # Collect dt_house_hold_id per cluster
    cluster_hhids = {}  # cluster_id -> set of household_ids
    for cid, members in clusters.items():
        hhids = set()
        for m in members:
            hh = m.get("dt_house_hold_id")
            if hh:
                hhids.add(str(hh))
        if hhids:
            cluster_hhids[cid] = hhids

    # Build household_id -> [cluster_ids]
    hh_to_clusters = defaultdict(set)
    for cid, hhids in cluster_hhids.items():
        for hh in hhids:
            hh_to_clusters[hh].add(cid)

    # For each cluster, compute household total and linked cluster IDs
    n_linked = 0
    for cid, prof in profiles.items():
        hhids = cluster_hhids.get(cid, set())
        if not hhids:
            prof["household_id"] = None
            prof["household_cluster_ids"] = []
            prof["household_total"] = prof["total_amount"]
            prof["household_n_clusters"] = 1
            continue

        # Collect all clusters in the same household(s)
        linked_cids = set()
        for hh in hhids:
            linked_cids.update(hh_to_clusters[hh])

        household_total = sum(profiles[c]["total_amount"] for c in linked_cids if c in profiles)
        other_cids = sorted(c for c in linked_cids if c != cid)

        prof["household_id"] = sorted(hhids)[0]  # primary household_id
        prof["household_cluster_ids"] = other_cids
        prof["household_total"] = round(household_total, 2)
        prof["household_n_clusters"] = len(linked_cids)

        if other_cids:
            n_linked += 1

    # Stats
    multi_member_hh = sum(1 for cids in hh_to_clusters.values() if len(cids) > 1)
    log.info(f"  Household linkage: {len(hh_to_clusters):,} households, "
             f"{multi_member_hh:,} with 2+ donors, {n_linked:,} clusters linked")
    log.info(f"  Household linkage built in {time.time()-t0:.1f}s")


# ── Write results ──

def write_clusters(conn, rows, uf, profiles, clusters):
    log.info("Writing cluster_id and cluster_profile to database...")
    t0 = time.time()

    with conn.cursor() as cur:
        # Use a single transaction — no blanket NULL reset
        batch = []
        for cid, members in clusters.items():
            prof_json = json.dumps(profiles[cid])
            ids = [m["id"] for m in members]
            batch.append((cid, prof_json, ids))

        # Batch update in chunks of 1000
        chunk_size = 1000
        for i in range(0, len(batch), chunk_size):
            chunk = batch[i:i + chunk_size]
            for cid, prof_json, ids in chunk:
                cur.execute(
                    "UPDATE raw.ncboe_donations SET cluster_id = %s, cluster_profile = %s::jsonb WHERE id = ANY(%s)",
                    (cid, prof_json, ids),
                )
            conn.commit()
            if (i + chunk_size) % 10000 == 0:
                log.info(f"  Written {i + chunk_size:,} / {len(batch):,} clusters...")

    log.info(f"  Wrote {len(batch):,} clusters in {time.time()-t0:.1f}s")


# ── Propagate rnc_regid within clusters ──

def propagate_ids(conn, clusters, profiles):
    """
    If a cluster has some rows with rnc_regid and some without,
    propagate the rnc_regid to the unmatched rows.
    """
    log.info("Propagating rnc_regid within clusters to dark donors...")
    t0 = time.time()

    propagated = 0
    dark_rescued = 0
    
    with conn.cursor() as cur:
        for cid, members in clusters.items():
            # Find the rnc_regid(s) in this cluster
            matched = [m for m in members if m.get("rnc_regid")]
            unmatched = [m for m in members if not m.get("rnc_regid")]

            if not matched or not unmatched:
                continue

            # Use the most common rnc_regid (should be 1 in most cases)
            regid_counts = defaultdict(int)
            for m in matched:
                regid_counts[m["rnc_regid"]] += 1
            best_regid = max(regid_counts, key=regid_counts.get)

            # Get full dt_* fields from the best matched row
            donor = next(m for m in matched if m["rnc_regid"] == best_regid)

            unmatched_ids = [m["id"] for m in unmatched]
            cur.execute("""
                UPDATE raw.ncboe_donations 
                SET rnc_regid = %s,
                    state_voter_id = %s,
                    dt_first = %s,
                    dt_middle = %s,
                    dt_last = %s,
                    dt_suffix = %s,
                    dt_prefix = %s,
                    dt_zip4 = %s,
                    dt_house_hold_id = %s,
                    dt_match_method = 'cluster_propagation'
                WHERE id = ANY(%s) AND rnc_regid IS NULL
            """, (
                donor.get("rnc_regid"),
                donor.get("state_voter_id"),
                donor.get("dt_first"),
                donor.get("dt_middle"),
                donor.get("norm_last"),
                donor.get("dt_suffix"),
                donor.get("dt_prefix"),
                donor.get("dt_zip4"),
                donor.get("dt_house_hold_id"),
                unmatched_ids,
            ))
            n = cur.rowcount
            propagated += n
            dark_rescued += n

        conn.commit()

    log.info(f"  Propagated rnc_regid to {propagated:,} previously-dark rows in {time.time()-t0:.1f}s")
    return propagated


# ── Statistics ──

def report_stats(rows, uf, clusters, profiles, propagated=0):
    n_clusters = len(clusters)
    n_singletons = sum(1 for c in clusters.values() if len(c) == 1)
    n_multi = n_clusters - n_singletons
    sizes = sorted([len(c) for c in clusters.values()], reverse=True)

    log.info("=" * 60)
    log.info("DEDUP RESULTS")
    log.info("=" * 60)
    log.info(f"  Total rows:           {len(rows):>12,}")
    log.info(f"  Total clusters:       {n_clusters:>12,}")
    log.info(f"  Singleton clusters:   {n_singletons:>12,}")
    log.info(f"  Multi-row clusters:   {n_multi:>12,}")
    log.info(f"  Largest cluster:      {sizes[0]:>12,} rows")
    log.info(f"  Top 10 clusters:      {sizes[:10]}")
    log.info(f"  IDs propagated:       {propagated:>12,}")

    # Size distribution
    size_buckets = defaultdict(int)
    for s in sizes:
        if s == 1:
            size_buckets["1 (singleton)"] += 1
        elif s <= 5:
            size_buckets["2-5"] += 1
        elif s <= 20:
            size_buckets["6-20"] += 1
        elif s <= 100:
            size_buckets["21-100"] += 1
        elif s <= 500:
            size_buckets["101-500"] += 1
        else:
            size_buckets["500+"] += 1

    log.info("  Size distribution:")
    for bucket in ["1 (singleton)", "2-5", "6-20", "21-100", "101-500", "500+"]:
        if bucket in size_buckets:
            log.info(f"    {bucket:>15s}: {size_buckets[bucket]:>8,}")

    # Clusters with rnc_regid
    matched_clusters = sum(1 for p in profiles.values() if p.get("rnc_regids"))
    log.info(f"  Clusters with rnc_regid: {matched_clusters:>8,}")

    # Ed Broyhill check
    for cid, prof in profiles.items():
        if "BROYHILL" in prof.get("last_names", []) and "27104" in prof.get("zip5s", []):
            if any(f in prof.get("name_variants_first", []) for f in ["ED", "EDGAR", "JAMES"]):
                log.info(f"  ED BROYHILL cluster {cid}:")
                log.info(f"    Names: {prof['name_variants_first']}")
                log.info(f"    Rows: {prof['n_rows']}")
                log.info(f"    Total: ${prof['total_amount']:,.2f}")
                log.info(f"    Years: {prof.get('year_min')}-{prof.get('year_max')}")
                log.info(f"    Employers: {prof['employers'][:5]}")
                log.info(f"    Zips: {prof['zip5s']}")
                log.info(f"    RNC IDs: {prof.get('rnc_regids', [])}")
                log.info(f"    Household ID: {prof.get('household_id')}")
                log.info(f"    Household total: ${prof.get('household_total', 0):,.2f}")
                log.info(f"    Household members: {prof.get('household_n_clusters', 1)} clusters")
                if prof.get('household_cluster_ids'):
                    for hc in prof['household_cluster_ids']:
                        hp = profiles.get(hc, {})
                        log.info(f"      Linked: cluster {hc} — {hp.get('name_variants_first', [])} {hp.get('last_names', [])} — ${hp.get('total_amount', 0):,.2f}")


# ── Main ──

def main():
    p = argparse.ArgumentParser(description="NCBOE Internal Dedup V2 — Complete 1A-1G")
    p.add_argument("--apply", action="store_true", help="Write results to DB (default: dry-run)")
    p.add_argument("--propagate-ids", action="store_true", help="Propagate rnc_regid within clusters")
    p.add_argument("--min-committee-shared", type=int, default=3, help="1C: min shared committees")
    args = p.parse_args()

    if not args.apply:
        log.info("DRY RUN — no changes will be written. Use --apply to write.")
    
    conn = psycopg2.connect(DB_URL)
    conn.autocommit = False

    rows, by_id = load_rows(conn)

    if not validate(rows):
        conn.close()
        return 1

    uf = UnionFind()

    # Initialize all IDs
    for r in rows:
        uf.find(r["id"])

    # Run stages in order
    total_merges = 0
    total_merges += stage_1a(rows, uf)
    total_merges += stage_1b(rows, uf)
    total_merges += stage_1c(rows, uf, min_shared=args.min_committee_shared)
    total_merges += stage_1d(rows, uf, by_id)
    total_merges += stage_1e(rows, uf, by_id)
    total_merges += stage_1f(rows, uf, by_id)
    total_merges += stage_1g(rows, uf, by_id)

    log.info(f"Total merges across all stages: {total_merges:,}")

    # Build profiles
    clusters, profiles = build_profiles(rows, uf, by_id)

    # Household linkage (separate from clustering)
    build_household_links(clusters, profiles)

    propagated = 0
    if args.apply:
        write_clusters(conn, rows, uf, profiles, clusters)
        if args.propagate_ids:
            propagated = propagate_ids(conn, clusters, profiles)
    
    report_stats(rows, uf, clusters, profiles, propagated)

    conn.close()
    log.info("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
