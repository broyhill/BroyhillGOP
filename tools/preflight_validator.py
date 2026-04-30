#!/usr/bin/env python3
"""
PREFLIGHT VALIDATOR — BroyhillGOP Database
==========================================
Run this BEFORE any session work. It checks the database for known problems
and prints a PASS/FAIL report. If anything fails, it tells you exactly what
to do next. No AI should proceed with work until all checks pass.

Usage:
    python3 /tools/preflight_validator.py

Exit codes:
    0 = all checks passed, safe to proceed
    1 = one or more checks failed, DO NOT proceed until resolved
    2 = connection failure

Design philosophy:
    - This script is the FIRST thing any AI runs, every session, no exceptions
    - It replaces Ed having to be the guardrail. The script IS the guardrail.
    - Every check has a WHAT TO DO if it fails — not just "it's broken"
    - New checks get added as new problems are discovered (append, never delete)
    - Ed's canary values are hardcoded here and updated when Phase 1 completes

History:
    2026-04-15  Created by Perplexity after discovering 7.4x spine inflation
"""

import sys
import json
import datetime
import psycopg2

# ════════════════════════════════════════════════════════════════════════════
# CONFIGURATION — Update these values as the database evolves
# ════════════════════════════════════════════════════════════════════════════

DB_CONN = "host=37.27.169.232 port=5432 dbname=postgres user=postgres password=${PG_PASSWORD}"

# Ed's canary cluster — the source of truth
ED_CLUSTER = 372171
ED_RNC_REGID = "c45eeea9-663f-40e1-b0e7-a473baee794e"

# ── Spine canary values ──
# IMPORTANT: These are the CURRENT (inflated) values in the database.
# After Phase 1 transaction dedup, update these to the real values.
# The script checks BOTH inflated and real depending on whether
# is_primary_txn column exists.
SPINE_CANARY = {
    "inflated": {
        "txns": 627,
        "total": 1318672.04,
        "description": "Pre-dedup (inflated — 18 source files overlapping)"
    },
    "deduped": {
        "txns": 147,
        "total": 332631.30,
        "description": "Post-dedup (real unique transactions)"
    }
}

# Party table canary — these should NEVER change
PARTY_CANARY = {
    "txns": 40,
    "total": 155945.45
}

# Combined real total (after spine dedup + party)
ED_REAL_COMBINED = 488576.75

# ── Table expected counts ──
# Format: (schema.table, expected_count, tolerance_pct, description)
# tolerance_pct: how much the count can deviate (0 = exact match required)
EXPECTED_COUNTS = [
    ("raw.ncboe_donations", 2431198, 0, "Spine — sacred, never changes"),
    ("staging.ncboe_party_committee_donations", 518077, 0, "Party table — separate load"),
    ("core.datatrust_voter_nc", 7727637, 0, "DataTrust voter file"),
    ("committee.registry", 10975, 0, "Committee registry from Supabase"),
]

# ── Contact enrichment expected minimums ──
# These are floors — the actual counts should be >= these values
CONTACT_MINIMUMS = {
    "cell_phone": 1473000,
    "home_phone": 1483000,
    "personal_email": 984000,
    "business_email": 342000,
}

# ── Known contamination patterns ──
# Things that should NEVER be true
CONTAMINATION_CHECKS = [
    {
        "name": "jsneeden@msn.com on Ed's cluster",
        "sql": """
            SELECT COUNT(*) FROM raw.ncboe_donations
            WHERE cluster_id = 372171 AND personal_email = 'jsneeden@msn.com'
        """,
        "expected": 0,
        "fix": "UPDATE raw.ncboe_donations SET personal_email = NULL WHERE cluster_id = 372171 AND personal_email = 'jsneeden@msn.com'"
    },
    {
        "name": "Ed's zip should be 27104 not 27105 in person_master",
        "sql": """
            SELECT COUNT(*) FROM donor_intelligence.person_master
            WHERE person_id = 372171 AND zip5 = '27105'
        """,
        "expected": 0,
        "fix": "UPDATE donor_intelligence.person_master SET zip5 = '27104' WHERE person_id = 372171",
        "skip_if_empty": "donor_intelligence.person_master"
    },
]

# ════════════════════════════════════════════════════════════════════════════
# CHECK ENGINE
# ════════════════════════════════════════════════════════════════════════════

class CheckResult:
    def __init__(self, name, passed, message, fix=None, severity="FAIL"):
        self.name = name
        self.passed = passed
        self.message = message
        self.fix = fix  # What to do if it failed
        self.severity = severity  # FAIL, WARN, INFO

    def __str__(self):
        status = "✓ PASS" if self.passed else f"✗ {self.severity}"
        line = f"  {status:10s} {self.name}: {self.message}"
        if not self.passed and self.fix:
            line += f"\n             FIX: {self.fix}"
        return line


def run_checks():
    """Run all preflight checks. Returns (results, conn) or exits on connection failure."""
    results = []

    # ── Connection test ──
    try:
        conn = psycopg2.connect(DB_CONN)
        conn.autocommit = True
        cur = conn.cursor()
        results.append(CheckResult("Database connection", True, "Connected to Hetzner PostgreSQL"))
    except Exception as e:
        print(f"\n✗ FATAL: Cannot connect to database: {e}")
        print(f"  Connection string: host=37.27.169.232 port=5432 dbname=postgres")
        print(f"  Is the server running? Is port 5432 accessible?")
        sys.exit(2)

    # ── Check 1: Spine row count ──
    cur.execute("SELECT COUNT(*) FROM raw.ncboe_donations")
    spine_count = cur.fetchone()[0]
    expected = 2431198
    passed = spine_count == expected
    results.append(CheckResult(
        "Spine row count",
        passed,
        f"{spine_count:,} rows (expected {expected:,})",
        fix="STOP — spine row count has changed. Check if someone ran DELETE/INSERT. Do NOT proceed." if not passed else None,
        severity="FAIL"
    ))

    # ── Check 2: Is is_primary_txn column present? ──
    cur.execute("""
        SELECT COUNT(*) FROM information_schema.columns
        WHERE table_schema = 'raw' AND table_name = 'ncboe_donations'
        AND column_name = 'is_primary_txn'
    """)
    has_dedup_col = cur.fetchone()[0] > 0

    if has_dedup_col:
        # Check how many are marked as primary
        cur.execute("SELECT COUNT(*) FROM raw.ncboe_donations WHERE is_primary_txn = true")
        primary_count = cur.fetchone()[0]
        results.append(CheckResult(
            "Transaction dedup column",
            True,
            f"is_primary_txn exists — {primary_count:,} primary rows marked",
            severity="INFO"
        ))

        # If populated, use deduped canary values
        if primary_count > 0:
            cur.execute("""
                SELECT COUNT(*), ROUND(SUM(norm_amount)::numeric, 2)
                FROM raw.ncboe_donations
                WHERE cluster_id = %s AND is_primary_txn = true
            """, (ED_CLUSTER,))
            r = cur.fetchone()
            ed_txns, ed_total = r[0], float(r[1] or 0)
            expected_txns = SPINE_CANARY["deduped"]["txns"]
            expected_total = SPINE_CANARY["deduped"]["total"]
            passed = ed_txns == expected_txns and abs(ed_total - expected_total) < 0.01
            results.append(CheckResult(
                "Ed canary (deduped spine)",
                passed,
                f"{ed_txns} txns / ${ed_total:,.2f} (expected {expected_txns} / ${expected_total:,.2f})",
                fix=f"Ed's deduped canary is wrong. Expected {expected_txns} txns / ${expected_total:,.2f}. Investigate is_primary_txn marking." if not passed else None
            ))
        else:
            results.append(CheckResult(
                "Transaction dedup status",
                False,
                "is_primary_txn column exists but NO rows marked. Phase 1 incomplete.",
                fix="Run Phase 1 from REVISED_PLAN_APR15.md — mark primary transactions.",
                severity="WARN"
            ))
    else:
        results.append(CheckResult(
            "Transaction dedup column",
            False,
            "is_primary_txn column does NOT exist — spine is still inflated 7.4x",
            fix="Run Phase 1 from REVISED_PLAN_APR15.md — add is_primary_txn column and mark primary transactions.",
            severity="WARN"
        ))

    # ── Check 3: Ed canary (inflated spine — always check regardless of dedup status) ──
    cur.execute("""
        SELECT COUNT(*), ROUND(SUM(norm_amount)::numeric, 2)
        FROM raw.ncboe_donations WHERE cluster_id = %s
    """, (ED_CLUSTER,))
    r = cur.fetchone()
    ed_txns_all, ed_total_all = r[0], float(r[1] or 0)
    expected_txns = SPINE_CANARY["inflated"]["txns"]
    expected_total = SPINE_CANARY["inflated"]["total"]
    passed = ed_txns_all == expected_txns and abs(ed_total_all - expected_total) < 0.01
    results.append(CheckResult(
        "Ed canary (full spine)",
        passed,
        f"{ed_txns_all} txns / ${ed_total_all:,.2f} (expected {expected_txns} / ${expected_total:,.2f})",
        fix=f"Ed's spine canary CHANGED. Someone modified raw.ncboe_donations. STOP IMMEDIATELY." if not passed else None
    ))

    # ── Check 4: Ed party canary ──
    cur.execute("""
        SELECT COUNT(*), ROUND(SUM(amount::numeric)::numeric, 2)
        FROM staging.ncboe_party_committee_donations WHERE cluster_id = %s
    """, (ED_CLUSTER,))
    r = cur.fetchone()
    ed_party_txns, ed_party_total = r[0], float(r[1] or 0)
    passed = ed_party_txns == PARTY_CANARY["txns"] and abs(ed_party_total - PARTY_CANARY["total"]) < 0.01
    results.append(CheckResult(
        "Ed canary (party table)",
        passed,
        f"{ed_party_txns} txns / ${ed_party_total:,.2f} (expected {PARTY_CANARY['txns']} / ${PARTY_CANARY['total']:,.2f})",
        fix="Ed's party canary CHANGED. Someone modified staging.ncboe_party_committee_donations. STOP." if not passed else None
    ))

    # ── Check 5: Party matching status ──
    cur.execute("""
        SELECT
            COUNT(*) FILTER (WHERE cluster_id IS NOT NULL) as linked,
            COUNT(*) FILTER (WHERE cluster_id IS NULL AND is_aggregated = false
                            AND transaction_type = 'Individual'
                            AND norm_last IS NOT NULL AND norm_last != '') as ind_unlinked,
            COUNT(*) FILTER (WHERE is_aggregated = true) as aggregated,
            COUNT(*) as total
        FROM staging.ncboe_party_committee_donations
    """)
    r = cur.fetchone()
    linked, ind_unlinked, aggregated, total = r
    results.append(CheckResult(
        "Party matching status",
        True,
        f"{linked:,} linked / {total:,} total ({100*linked/total:.1f}%), {ind_unlinked:,} individual unlinked, {aggregated:,} aggregated",
        severity="INFO"
    ))

    # ── Check 6: Table row counts ──
    for table, expected, tolerance, desc in EXPECTED_COUNTS:
        try:
            cur.execute(f"SELECT COUNT(*) FROM {table}")
            actual = cur.fetchone()[0]
            if tolerance == 0:
                passed = actual == expected
            else:
                passed = abs(actual - expected) / expected <= tolerance / 100
            results.append(CheckResult(
                f"Row count: {table}",
                passed,
                f"{actual:,} (expected {expected:,}) — {desc}",
                fix=f"Row count mismatch on {table}. Investigate before proceeding." if not passed else None
            ))
        except psycopg2.Error as e:
            results.append(CheckResult(
                f"Row count: {table}",
                False,
                f"Query failed: {e}",
                fix=f"Table {table} may not exist or may be inaccessible.",
                severity="WARN"
            ))

    # ── Check 7: Contact enrichment ──
    for field, minimum in CONTACT_MINIMUMS.items():
        cur.execute(f"SELECT COUNT(*) FROM raw.ncboe_donations WHERE {field} IS NOT NULL")
        actual = cur.fetchone()[0]
        passed = actual >= minimum
        results.append(CheckResult(
            f"Contact: {field}",
            passed,
            f"{actual:,} rows (minimum {minimum:,})",
            fix=f"Contact enrichment for {field} appears degraded. Was a rollback run?" if not passed else None
        ))

    # ── Check 8: Contamination patterns ──
    for check in CONTAMINATION_CHECKS:
        skip_table = check.get("skip_if_empty")
        if skip_table:
            try:
                cur.execute(f"SELECT COUNT(*) FROM {skip_table}")
                if cur.fetchone()[0] == 0:
                    results.append(CheckResult(
                        f"Contamination: {check['name']}",
                        True,
                        f"Skipped — {skip_table} is empty (not yet built)",
                        severity="INFO"
                    ))
                    continue
            except psycopg2.Error:
                continue

        try:
            cur.execute(check["sql"])
            actual = cur.fetchone()[0]
            passed = actual == check["expected"]
            results.append(CheckResult(
                f"Contamination: {check['name']}",
                passed,
                f"Found {actual} (expected {check['expected']})",
                fix=check.get("fix", "Investigate and clean manually.") if not passed else None
            ))
        except psycopg2.Error as e:
            results.append(CheckResult(
                f"Contamination: {check['name']}",
                True,
                f"Check skipped (table may not exist yet): {e}",
                severity="INFO"
            ))

    # ── Check 9: Rollup table status ──
    for table_name in ["donor_intelligence.contribution_map", "donor_intelligence.person_master"]:
        try:
            cur.execute(f"SELECT COUNT(*) FROM {table_name}")
            count = cur.fetchone()[0]
            if count == 0:
                results.append(CheckResult(
                    f"Rollup: {table_name}",
                    True,  # Not a failure — just not built yet
                    f"0 rows — not yet populated (blocked by spine transaction dedup)",
                    severity="INFO"
                ))
            else:
                results.append(CheckResult(
                    f"Rollup: {table_name}",
                    True,
                    f"{count:,} rows populated",
                    severity="INFO"
                ))
        except psycopg2.Error:
            results.append(CheckResult(
                f"Rollup: {table_name}",
                False,
                "Table does not exist",
                fix=f"Create {table_name} per the schema spec.",
                severity="WARN"
            ))

    # ── Check 10: Ed's rnc_regid integrity ──
    cur.execute("""
        SELECT COUNT(DISTINCT rnc_regid)
        FROM raw.ncboe_donations
        WHERE cluster_id = %s AND rnc_regid IS NOT NULL
    """, (ED_CLUSTER,))
    regid_count = cur.fetchone()[0]
    if regid_count == 1:
        cur.execute("""
            SELECT rnc_regid FROM raw.ncboe_donations
            WHERE cluster_id = %s AND rnc_regid IS NOT NULL LIMIT 1
        """, (ED_CLUSTER,))
        actual_regid = cur.fetchone()[0]
        passed = actual_regid == ED_RNC_REGID
        results.append(CheckResult(
            "Ed rnc_regid integrity",
            passed,
            f"Cluster 372171 has 1 rnc_regid: {actual_regid[:12]}...",
            fix=f"Ed's rnc_regid changed! Expected {ED_RNC_REGID}, got {actual_regid}" if not passed else None
        ))
    elif regid_count == 0:
        results.append(CheckResult(
            "Ed rnc_regid integrity",
            False,
            "Cluster 372171 has NO rnc_regid — voter link was lost",
            fix="Investigate — Ed's cluster should have rnc_regid c45eeea9-663f-40e1-b0e7-a473baee794e"
        ))
    else:
        results.append(CheckResult(
            "Ed rnc_regid integrity",
            False,
            f"Cluster 372171 has {regid_count} different rnc_regids — contamination",
            fix="Multiple voter IDs on one cluster. Investigate which is correct."
        ))

    cur.close()
    conn.close()
    return results


# ════════════════════════════════════════════════════════════════════════════
# REPORT
# ════════════════════════════════════════════════════════════════════════════

def print_report(results):
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")
    failures = [r for r in results if not r.passed and r.severity == "FAIL"]
    warnings = [r for r in results if not r.passed and r.severity == "WARN"]
    passes = [r for r in results if r.passed]

    print()
    print("=" * 76)
    print(f"  PREFLIGHT VALIDATOR — BroyhillGOP Database")
    print(f"  Run at: {now}")
    print("=" * 76)

    for r in results:
        print(r)

    print()
    print("-" * 76)
    print(f"  SUMMARY: {len(passes)} passed, {len(warnings)} warnings, {len(failures)} failures")
    print("-" * 76)

    if failures:
        print()
        print("  ✗✗✗ PREFLIGHT FAILED — DO NOT PROCEED ✗✗✗")
        print()
        print("  The following checks MUST be resolved before any work begins:")
        for f in failures:
            print(f"    • {f.name}: {f.message}")
            if f.fix:
                print(f"      FIX: {f.fix}")
        print()
        print("  Report these failures to Ed before attempting any fix.")
        return 1

    if warnings:
        print()
        print("  ⚠ PREFLIGHT PASSED WITH WARNINGS")
        print()
        print("  These are known issues that don't block work but need attention:")
        for w in warnings:
            print(f"    • {w.name}: {w.message}")
            if w.fix:
                print(f"      FIX: {w.fix}")
        print()
        print("  You may proceed, but address warnings when appropriate.")
        return 0

    print()
    print("  ✓ ALL CHECKS PASSED — SAFE TO PROCEED")
    print()
    return 0


# ════════════════════════════════════════════════════════════════════════════
# WHERE WE ARE — Determine current phase based on database state
# ════════════════════════════════════════════════════════════════════════════

def print_current_phase(results):
    """Based on check results, tell the AI exactly what to do next."""

    # Determine state from results
    has_dedup_col = any("is_primary_txn exists" in r.message for r in results)
    has_primary_marked = any("primary rows marked" in r.message and "0 primary" not in r.message for r in results)
    contrib_map_empty = any("contribution_map" in r.name and "0 rows" in r.message for r in results)
    person_master_empty = any("person_master" in r.name and "0 rows" in r.message for r in results)

    print()
    print("=" * 76)
    print("  CURRENT PHASE — WHAT TO DO NEXT")
    print("=" * 76)

    if not has_dedup_col:
        print("""
  ▸ PHASE 1: Transaction Deduplication (NOT STARTED)

    The spine is inflated 7.4x. Every dollar total and transaction count is wrong.
    NOTHING downstream works until this is fixed.

    Next action:
    1. Read REVISED_PLAN_APR15.md from the GitHub repo
    2. Present the three dedup options to Ed (view / mark-and-filter / true delete)
    3. Get Ed's decision
    4. Execute Phase 1 per the plan
    5. Re-run this preflight validator to confirm

    DO NOT proceed to contribution_map or person_master until Phase 1 is complete.
""")
    elif not has_primary_marked:
        print("""
  ▸ PHASE 1: Transaction Deduplication (COLUMN EXISTS, NOT POPULATED)

    The is_primary_txn column was added but no rows are marked.
    Run the UPDATE to mark primary transactions.

    See REVISED_PLAN_APR15.md Step 1B.2 for the exact SQL.
""")
    elif contrib_map_empty:
        print("""
  ▸ PHASE 4: Populate contribution_map

    Transaction dedup is complete. Now build the contribution_map.
    Use ONLY is_primary_txn = true rows from the spine.

    See REVISED_PLAN_APR15.md Phase 4 for the exact SQL.
    Ed canary: contribution_map for person_id=372171 should show $488,576.75.
""")
    elif person_master_empty:
        print("""
  ▸ PHASE 5: Populate person_master

    contribution_map is built. Now build person_master.
    One row per cluster with correct (non-inflated) totals.

    See REVISED_PLAN_APR15.md Phase 5 for the exact SQL.
    Ed canary: zip5 = 27104, NOT 27105.
""")
    else:
        print("""
  ▸ ALL CORE PHASES COMPLETE

    Spine deduped, contribution_map built, person_master built.
    Review REVISED_PLAN_APR15.md for remaining work:
    - Phase 8: Employer bridge for major donors
    - Committee non-individual transactions
    - Partitions #7 and #8 (DEADLINE: July 31)
""")


if __name__ == "__main__":
    results = run_checks()
    exit_code = print_report(results)
    print_current_phase(results)
    sys.exit(exit_code)
