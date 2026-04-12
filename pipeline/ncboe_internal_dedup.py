#!/usr/bin/env python3
"""
Stage 1 internal dedup (DONOR_DEDUP_PIPELINE_V2.md) for raw.ncboe_donations.

1A: (norm_last, norm_first, norm_zip5)
1B: (norm_last, norm_employer, norm_city) when all present
1C (light): (norm_last, norm_zip5, committee_sboe_id) with ≥min repeats → union all those rows

Then cluster_id := min(row id) in each connected component (stable label).
cluster_profile JSON: name variants, address numbers, addresses, employers, cities, zips, committees, sum amount.

Environment: DATABASE_URL / HETZNER_DB_URL / SUPABASE_DB_URL via pipeline.db.
"""

from __future__ import annotations

import argparse
import json
import logging
from collections import defaultdict

from pipeline.db import get_connection, init_pool

logger = logging.getLogger(__name__)


class UnionFind:
    def __init__(self) -> None:
        self._p: dict[int, int] = {}

    def find(self, x: int) -> int:
        if x not in self._p:
            self._p[x] = x
        if self._p[x] != x:
            self._p[x] = self.find(self._p[x])
        return self._p[x]

    def union(self, a: int, b: int) -> None:
        ra, rb = self.find(a), self.find(b)
        if ra == rb:
            return
        if ra < rb:
            self._p[rb] = ra
        else:
            self._p[ra] = rb


def run_stage1(conn, *, min_committee_repeat: int = 3) -> dict:
    uf = UnionFind()
    with conn.cursor() as cur:
        cur.execute(
            """
            SELECT id, norm_last, norm_first, norm_zip5, norm_employer, norm_city,
                   committee_sboe_id, year_donated, address_numbers, all_addresses,
                   name, employer_name, street_line_1, street_line_2, city, zip_code,
                   norm_amount, transction_type
            FROM raw.ncboe_donations
            ORDER BY year_donated DESC NULLS LAST, id ASC
            """
        )
        rows = cur.fetchall()

    root_1a: dict[tuple[str, str, str], int] = {}
    root_1b: dict[tuple[str, str, str], int] = {}

    for tup in rows:
        (
            rid,
            norm_last,
            norm_first,
            norm_zip5,
            norm_employer,
            norm_city,
            committee_sboe_id,
            year_donated,
            address_numbers,
            all_addresses,
            name,
            employer_name,
            street_line_1,
            street_line_2,
            city,
            zip_code,
            norm_amount,
            transction_type,
        ) = tup
        uf.find(rid)
        last, first, z5 = (norm_last or ""), (norm_first or ""), (norm_zip5 or "")
        emp, cit = (norm_employer or ""), (norm_city or "")
        if last and first and z5:
            k = (last, first, z5)
            if k not in root_1a:
                root_1a[k] = rid
            uf.union(rid, root_1a[k])
        if last and emp and cit:
            k2 = (last, emp, cit)
            if k2 not in root_1b:
                root_1b[k2] = rid
            uf.union(rid, root_1b[k2])

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

    # Canonical cluster label = min id in component
    comp_members: defaultdict[int, list[int]] = defaultdict(list)
    for tup in rows:
        rid = tup[0]
        root = uf.find(rid)
        comp_members[root].append(rid)
    canonical: dict[int, int] = {root: min(members) for root, members in comp_members.items()}
    row_cluster: dict[int, int] = {rid: canonical[uf.find(rid)] for tup in rows for rid in [tup[0]]}

    clusters: dict[int, list[dict]] = defaultdict(list)
    for tup in rows:
        (
            rid,
            norm_last,
            norm_first,
            norm_zip5,
            norm_employer,
            norm_city,
            committee_sboe_id,
            year_donated,
            address_numbers,
            all_addresses,
            name,
            employer_name,
            street_line_1,
            street_line_2,
            city,
            zip_code,
            norm_amount,
            transction_type,
        ) = tup
        cid = row_cluster[rid]
        clusters[cid].append(
            {
                "id": rid,
                "name": name,
                "norm_first": norm_first,
                "norm_last": norm_last,
                "norm_zip5": norm_zip5,
                "norm_employer": norm_employer,
                "norm_city": norm_city,
                "committee_sboe_id": committee_sboe_id,
                "year_donated": year_donated,
                "address_numbers": address_numbers,
                "all_addresses": all_addresses,
                "street_line_1": street_line_1,
                "street_line_2": street_line_2,
                "city": city,
                "zip_code": zip_code,
                "norm_amount": float(norm_amount) if norm_amount is not None else None,
                "transction_type": transction_type,
            }
        )

    with conn.cursor() as cur:
        cur.execute("UPDATE raw.ncboe_donations SET cluster_id = NULL, cluster_profile = NULL")
        for cid, members in clusters.items():
            firsts = sorted({m["norm_first"] for m in members if m.get("norm_first")})
            nums: set[str] = set()
            addrs: set[str] = set()
            emps: set[str] = set()
            cities: set[str] = set()
            zips: set[str] = set()
            committees: set[str] = set()
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
            prof = {
                "cluster_id": cid,
                "n_rows": len(members),
                "name_variants_first": firsts,
                "address_numbers": sorted(nums),
                "addresses": sorted(addrs),
                "employers": sorted(emps),
                "cities": sorted(cities),
                "zip5s": sorted(zips),
                "committees": sorted(committees),
                "total_amount": sum((m["norm_amount"] or 0) for m in members),
            }
            js = json.dumps(prof)
            ids = [m["id"] for m in members]
            cur.execute(
                "UPDATE raw.ncboe_donations SET cluster_id = %s, cluster_profile = %s::jsonb WHERE id = ANY(%s)",
                (cid, js, ids),
            )
    conn.commit()
    return {"clusters": len(clusters), "rows": len(rows)}


def main() -> int:
    logging.basicConfig(level=logging.INFO, format="%(levelname)s %(message)s")
    p = argparse.ArgumentParser(description="NCBOE internal dedup Stage 1")
    p.add_argument("--min-committee-repeat", type=int, default=3, help="1C threshold")
    args = p.parse_args()
    init_pool()
    with get_connection() as conn:
        info = run_stage1(conn, min_committee_repeat=args.min_committee_repeat)
    logger.info("Stage1 complete: %s", info)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
