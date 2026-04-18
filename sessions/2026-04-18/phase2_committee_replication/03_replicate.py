#!/usr/bin/env python3
"""
Phase 2 Committee Replication: Supabase -> Hetzner

End-to-end replicator for the 3 committee matching-machine tables that were
still only in Supabase as of 2026-04-18 (the other 10 were moved on April 15).

Can be run in two phases if sandbox egress to Hetzner is blocked:
  python 03_replicate.py extract                 # Supabase REST -> CSV on disk
  python 03_replicate.py load                    # CSV -> Hetzner COPY FROM STDIN
  python 03_replicate.py verify                  # row-count + canary checks
  python 03_replicate.py all                     # extract + load + verify

Authored by Nexus 2026-04-18.
Guard rails enforced (see database-operations skill):
  - CREATE TABLE IF NOT EXISTS only (DDL applied separately by 01_hetzner_ddl.sql)
  - Refuses to load into a non-empty target unless --force is passed
  - No TRUNCATE. No DROP. No mutation of any existing table.
"""

import argparse
import csv
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path

import requests

try:
    import psycopg2
    from psycopg2 import sql
except ImportError:
    psycopg2 = None  # only needed for the load phase

# ---------------------------------------------------------------------------
# CONFIG
# ---------------------------------------------------------------------------

SUPABASE_URL = "https://isbgjpnbocdkeslofota.supabase.co"
# Legacy anon key — publicly reachable, read-only access only to these 3 RPCs
SUPABASE_ANON = (
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9."
    "eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzYmdqcG5ib2Nka2VzbG9mb3RhIiwicm9sZSI6"
    "ImFub24iLCJpYXQiOjE3NjQ3MDc3MDcsImV4cCI6MjA4MDI4MzcwN30."
    "pSF0-C-QOklmDWtbexUvnFphuz_bFTdF4INaBMSW1SM"
)

# Hetzner target
HETZNER_HOST = os.environ.get("HETZNER_HOST", "37.27.169.232")
HETZNER_PORT = int(os.environ.get("HETZNER_PORT", 5432))
HETZNER_DB   = os.environ.get("HETZNER_DB",   "postgres")
HETZNER_USER = os.environ.get("HETZNER_USER", "postgres")
HETZNER_PW   = os.environ.get("HETZNER_PW",   "XanypdTxZb3qRE8bUdGXFGGK")

# Page size: 1000 rows per RPC call (proved safe under the 30KB response cap
# in the April 15 replication).
PAGE_SIZE = 1000
MAX_RETRIES = 5
RETRY_BACKOFF_SEC = 3

OUT_DIR = Path(__file__).parent / "csv"
OUT_DIR.mkdir(exist_ok=True)

# ---------------------------------------------------------------------------
# TABLE DEFINITIONS
#   supabase_rpc  = name of the SECURITY DEFINER function (applied in 02_supabase_rpc.sql)
#   hetzner_table = fully-qualified target on Hetzner (created by 01_hetzner_ddl.sql)
#   columns       = ordered column list for COPY — must match 01_hetzner_ddl.sql
#   order_key     = the column used by the RPC's ORDER BY (for cursor-less pagination)
#   expected_rows = row count as of 2026-04-18 snapshot on Supabase
# ---------------------------------------------------------------------------

TABLES = [
    {
        "name": "boe_donation_candidate_map",
        "supabase_rpc": "export_boe_donation_candidate_map",
        "hetzner_table": "committee.boe_donation_candidate_map",
        "expected_rows": 338213,
        "order_key": "boe_id",
        "columns": [
            "boe_id", "donor_name", "norm_last", "norm_first", "norm_zip5",
            "amount_numeric", "date_occurred", "election_year",
            "committee_sboe_id", "committee_name", "committee_type",
            "source_level", "committee_total_received", "fec_committee_id",
            "candidate_name", "contest_name", "candidate_county",
            "candidate_party", "filing_date", "election_dt",
            "office_level", "district_number", "partisan_flag",
        ],
    },
    {
        "name": "ncsbe_candidates_full",
        "supabase_rpc": "export_ncsbe_candidates_full",
        "hetzner_table": "committee.ncsbe_candidates_full",
        "expected_rows": 55985,
        "order_key": "id",
        "columns": [
            "id", "election_dt", "county_name", "contest_name",
            "name_on_ballot", "first_name", "middle_name", "last_name",
            "name_suffix_lbl", "nick_name", "street_address", "city", "state",
            "zip", "election_dt_original", "contest_original",
            "party_candidate", "party_contest", "is_partisan", "vote_for",
            "term", "created_at", "phone", "email", "filing_date",
            "import_batch", "committee_sboe_id",
        ],
    },
    {
        "name": "fec_committee_candidate_lookup",
        "supabase_rpc": "export_fec_committee_candidate_lookup",
        "hetzner_table": "committee.fec_committee_candidate_lookup",
        "expected_rows": 2012,
        "order_key": "id",
        "columns": [
            "id", "committee_id", "committee_name", "committee_type",
            "committee_designation", "committee_party", "committee_state",
            "candidate_id", "candidate_name", "candidate_last_name",
            "candidate_first_name", "candidate_party", "candidate_office",
            "candidate_office_state", "candidate_office_district",
            "election_year", "match_method", "match_confidence",
            "donation_count", "total_donated", "created_at", "updated_at",
        ],
    },
]

# ---------------------------------------------------------------------------
# EXTRACT PHASE — Supabase REST API pagination -> CSV
# ---------------------------------------------------------------------------

def rpc_page(rpc_name, offset, limit):
    """Call a Supabase RPC with retry/backoff. Returns a list of dicts."""
    url = f"{SUPABASE_URL}/rest/v1/rpc/{rpc_name}"
    headers = {
        "apikey": SUPABASE_ANON,
        "Authorization": f"Bearer {SUPABASE_ANON}",
        "Content-Type": "application/json",
        "Accept-Profile": "public",
    }
    payload = {"p_offset": offset, "p_limit": limit}

    last_err = None
    for attempt in range(1, MAX_RETRIES + 1):
        try:
            r = requests.post(url, headers=headers, json=payload, timeout=90)
            r.raise_for_status()
            data = r.json()
            if not isinstance(data, list):
                raise RuntimeError(f"Unexpected RPC response shape: {type(data).__name__}")
            return data
        except Exception as e:
            last_err = e
            sleep = RETRY_BACKOFF_SEC * attempt
            print(f"    retry {attempt}/{MAX_RETRIES} on {rpc_name}@{offset} "
                  f"({type(e).__name__}: {str(e)[:120]}) — sleeping {sleep}s",
                  file=sys.stderr)
            time.sleep(sleep)
    raise RuntimeError(f"RPC failed after {MAX_RETRIES} retries: {rpc_name} "
                       f"offset={offset} — last error: {last_err!r}")


def extract_table(tdef):
    """Paginate through a Supabase RPC, writing a CSV with the exact column
    order required by Hetzner's COPY target."""
    name = tdef["name"]
    rpc  = tdef["supabase_rpc"]
    cols = tdef["columns"]
    csv_path = OUT_DIR / f"{name}.csv"

    t0 = time.time()
    offset = 0
    total = 0
    pages = 0

    with csv_path.open("w", newline="", encoding="utf-8") as fh:
        w = csv.writer(fh, quoting=csv.QUOTE_MINIMAL, lineterminator="\n")
        w.writerow(cols)  # header

        while True:
            rows = rpc_page(rpc, offset, PAGE_SIZE)
            if not rows:
                break
            for r in rows:
                w.writerow([
                    "" if r.get(c) is None else r.get(c)
                    for c in cols
                ])
            n = len(rows)
            total += n
            pages += 1
            if pages % 25 == 0 or n < PAGE_SIZE:
                rate = total / max(time.time() - t0, 0.01)
                print(f"  [{name}] page={pages} offset={offset} rows={total:,} "
                      f"({rate:,.0f} rows/sec)")
            if n < PAGE_SIZE:
                break
            offset += PAGE_SIZE

    elapsed = time.time() - t0
    print(f"  [{name}] EXTRACT DONE: {total:,} rows in {elapsed:,.1f}s "
          f"-> {csv_path} ({csv_path.stat().st_size:,} bytes)")
    if total != tdef["expected_rows"]:
        print(f"  [{name}] WARNING: expected {tdef['expected_rows']:,}, got {total:,}")
    return total


def cmd_extract():
    print(f"== EXTRACT phase @ {datetime.utcnow().isoformat()}Z ==")
    print(f"   Source: {SUPABASE_URL}")
    print(f"   Output: {OUT_DIR}")
    totals = {}
    for tdef in TABLES:
        print(f"\n-> {tdef['name']} (expecting ~{tdef['expected_rows']:,} rows)")
        totals[tdef["name"]] = extract_table(tdef)
    print("\n== EXTRACT SUMMARY ==")
    for t, n in totals.items():
        print(f"   {t:45s} {n:>10,} rows")
    return totals

# ---------------------------------------------------------------------------
# LOAD PHASE — CSV -> Hetzner COPY FROM STDIN
# ---------------------------------------------------------------------------

def hetzner_connect():
    if psycopg2 is None:
        raise RuntimeError("psycopg2 is required for the load phase (pip install psycopg2-binary)")
    return psycopg2.connect(
        host=HETZNER_HOST, port=HETZNER_PORT, dbname=HETZNER_DB,
        user=HETZNER_USER, password=HETZNER_PW, connect_timeout=15,
        sslmode="prefer",
    )


def target_rowcount(conn, fq_table):
    schema, tbl = fq_table.split(".")
    with conn.cursor() as cur:
        cur.execute(
            sql.SQL("SELECT COUNT(*) FROM {}.{}").format(
                sql.Identifier(schema), sql.Identifier(tbl)
            )
        )
        return cur.fetchone()[0]


def load_table(conn, tdef, force=False):
    name = tdef["name"]
    target = tdef["hetzner_table"]
    cols = tdef["columns"]
    csv_path = OUT_DIR / f"{name}.csv"
    if not csv_path.exists():
        raise RuntimeError(f"CSV not found: {csv_path} (run extract first)")

    existing = target_rowcount(conn, target)
    if existing > 0 and not force:
        raise RuntimeError(
            f"Refusing to load: {target} already has {existing:,} rows. "
            f"Pass --force to proceed anyway (will append, NOT truncate)."
        )
    if existing > 0 and force:
        print(f"  [{name}] WARNING: {target} already has {existing:,} rows. "
              f"--force given; APPENDING.")

    t0 = time.time()
    with conn.cursor() as cur, csv_path.open("r", encoding="utf-8") as fh:
        copy_sql = sql.SQL(
            "COPY {}.{} ({}) FROM STDIN WITH (FORMAT csv, HEADER true, NULL '')"
        ).format(
            sql.Identifier(*target.split(".")[:1]),
            sql.Identifier(target.split(".")[1]),
            sql.SQL(", ").join(sql.Identifier(c) for c in cols),
        )
        cur.copy_expert(copy_sql.as_string(conn), fh)
    conn.commit()

    after = target_rowcount(conn, target)
    loaded = after - existing
    elapsed = time.time() - t0
    print(f"  [{name}] LOAD DONE: +{loaded:,} rows in {elapsed:,.1f}s "
          f"(target now {after:,})")
    if loaded != tdef["expected_rows"] and not force:
        print(f"  [{name}] WARNING: expected +{tdef['expected_rows']:,}, loaded +{loaded:,}")
    return loaded


def cmd_load(force=False):
    print(f"== LOAD phase @ {datetime.utcnow().isoformat()}Z ==")
    print(f"   Target: {HETZNER_USER}@{HETZNER_HOST}:{HETZNER_PORT}/{HETZNER_DB}")
    conn = hetzner_connect()
    print(f"   Connected. server_version={conn.server_version}")
    try:
        for tdef in TABLES:
            print(f"\n-> {tdef['name']}")
            load_table(conn, tdef, force=force)
    finally:
        conn.close()

# ---------------------------------------------------------------------------
# VERIFY PHASE — row counts + canary
# ---------------------------------------------------------------------------

def cmd_verify():
    print(f"== VERIFY phase @ {datetime.utcnow().isoformat()}Z ==")
    conn = hetzner_connect()
    try:
        with conn.cursor() as cur:
            print("\n1) Sacred spine (must NOT have been touched):")
            cur.execute("""SELECT COUNT(*)::bigint, COUNT(DISTINCT cluster_id)::bigint
                           FROM raw.ncboe_donations""")
            rows, clusters = cur.fetchone()
            print(f"   raw.ncboe_donations  rows={rows:,} clusters={clusters:,}")
            if (rows, clusters) != (321348, 98303):
                print(f"   !! STOP: expected 321,348 rows / 98,303 clusters")
                return False

            print("\n2) Ed canary (cluster 372171):")
            cur.execute("""SELECT COUNT(*), SUM(norm_amount),
                                  MAX(personal_email), MAX(cell_phone)
                           FROM raw.ncboe_donations WHERE cluster_id=372171""")
            n, total, pe, ph = cur.fetchone()
            print(f"   txns={n}  total={total}  p_email={pe}  cell={ph}")
            if n != 147 or abs(float(total) - 332631.30) > 0.01:
                print("   !! STOP: canary drift")
                return False

            print("\n3) Phase 2 target row counts:")
            for tdef in TABLES:
                cur.execute(sql.SQL("SELECT COUNT(*) FROM {}.{}").format(
                    sql.Identifier(*tdef["hetzner_table"].split(".")[:1]),
                    sql.Identifier(tdef["hetzner_table"].split(".")[1]),
                ))
                n = cur.fetchone()[0]
                delta = n - tdef["expected_rows"]
                flag = "OK " if delta == 0 else "!! "
                print(f"   {flag}{tdef['hetzner_table']:55s} "
                      f"rows={n:>10,}  expected={tdef['expected_rows']:>10,}  "
                      f"delta={delta:+,}")

            print("\n4) BOE donation -> candidate match rate:")
            cur.execute("""
              SELECT COUNT(*)                                         AS total,
                     COUNT(*) FILTER (WHERE candidate_name IS NOT NULL) AS matched,
                     ROUND(100.0 * COUNT(*) FILTER (WHERE candidate_name IS NOT NULL)
                                 / NULLIF(COUNT(*),0), 2) AS match_pct
              FROM committee.boe_donation_candidate_map
            """)
            tot, matched, pct = cur.fetchone()
            print(f"   total={tot:,}  matched={matched:,}  match_rate={pct}%")
            print("   (April 1 Cursor audit claimed 99.67% — if still 73.9% we need to "
                  "figure out whether the audit was on a filtered subset or the table "
                  "regressed)")

            print("\n5) Committee matching-machine dashboard view:")
            cur.execute("SELECT tbl, rows, expected, (rows-expected) AS delta "
                        "FROM committee.v_matching_machine_status ORDER BY tbl")
            for row in cur.fetchall():
                print(f"   {row[0]:55s} rows={row[1]:>10,}  expected={row[2]:>10,}  delta={row[3]:+,}")

        return True
    finally:
        conn.close()

# ---------------------------------------------------------------------------
# MAIN
# ---------------------------------------------------------------------------

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("phase", choices=["extract", "load", "verify", "all"])
    ap.add_argument("--force", action="store_true",
                    help="Allow load into a non-empty target (append; never truncates)")
    args = ap.parse_args()

    if args.phase in ("extract", "all"):
        cmd_extract()
    if args.phase in ("load", "all"):
        cmd_load(force=args.force)
    if args.phase in ("verify", "all"):
        ok = cmd_verify()
        sys.exit(0 if ok else 2)


if __name__ == "__main__":
    main()
