#!/usr/bin/env python3
"""
CURSOR COMMAND BRIEF GENERATOR — BroyhillGOP Database
=====================================================
Generates single-task command files for Cursor to execute.
Each task is one play — one SQL block, one expected result,
one canary check, one rollback plan, one stop condition.

Cursor picks up the task, executes it, writes the result.
The leading AI reads the result, validates, generates the next task.
Ed sees both: the task that was issued and the result that came back.

This is a PLAY-BY-PLAY system. Cursor never freelances.

Usage:
    # Generate the next task based on current database state:
    python3 /tools/cursor_command_brief.py --generate

    # Generate a specific task by name:
    python3 /tools/cursor_command_brief.py --task phase1_add_column

    # List all available tasks:
    python3 /tools/cursor_command_brief.py --list

    # Record a result (Cursor runs this after executing):
    python3 /tools/cursor_command_brief.py --result TASK_ID --status pass --output "147 txns, $332,631.30"

File structure:
    /tools/cursor_tasks/         — Generated task files (CURSOR reads these)
    /tools/cursor_results/       — Result files (Cursor writes, AI reads)
    /tools/cursor_task_log.json  — Audit log of all tasks issued and results

Design:
    - Each task file is self-contained: SQL, expected output, canary, rollback
    - Task files are numbered sequentially: TASK_001.md, TASK_002.md, etc.
    - Result files mirror: RESULT_001.md, RESULT_002.md
    - The audit log tracks what happened and when
    - Tasks are idempotent where possible — safe to re-run if interrupted

History:
    2026-04-15  Created by Perplexity per Ed's directive:
                "Cursor is better suited for tedious work. he needs to
                consult every play."
"""

import sys
import os
import json
import argparse
import datetime
import psycopg2

DB_CONN = "host=37.27.169.232 port=5432 dbname=postgres user=postgres password=${PG_PASSWORD}"

TASK_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cursor_tasks")
RESULT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cursor_results")
LOG_FILE = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cursor_task_log.json")

# ════════════════════════════════════════════════════════════════════════════
# TASK DEFINITIONS
# Each task is one play. Order matters — each depends on the previous.
# ════════════════════════════════════════════════════════════════════════════

TASK_REGISTRY = {

    # ── PHASE 1: Transaction Deduplication ──

    "phase1_add_column": {
        "phase": 1,
        "name": "Add is_primary_txn Column",
        "description": """
Add the is_primary_txn boolean column to raw.ncboe_donations.
This column will mark which row is the 'primary' representative
for each unique transaction. The 18 NCBOE source files contain
overlapping donations — the same transaction appears in multiple
files with only source_file differing. This column identifies
the one row to keep per unique transaction.

⚠️ REQUIRES ED AUTHORIZATION — this is DDL on raw.ncboe_donations.
Show Ed this task file and wait for: "I AUTHORIZE THIS ACTION"
""",
        "authorization_required": True,
        "sql": """
-- Add the column (safe — does not modify existing data)
ALTER TABLE raw.ncboe_donations
ADD COLUMN IF NOT EXISTS is_primary_txn boolean DEFAULT false;

-- Verify column exists
SELECT column_name, data_type, column_default
FROM information_schema.columns
WHERE table_schema = 'raw'
  AND table_name = 'ncboe_donations'
  AND column_name = 'is_primary_txn';
""",
        "expected_output": "Column 'is_primary_txn' exists with type boolean, default false",
        "canary_check": """
-- Ed canary — spine must be unchanged
SELECT COUNT(*) as txns, ROUND(SUM(norm_amount)::numeric, 2) as total
FROM raw.ncboe_donations WHERE cluster_id = 372171;
-- MUST BE: 627 txns, $1,318,672.04
""",
        "canary_values": {"txns": 627, "total": 1318672.04},
        "rollback": "ALTER TABLE raw.ncboe_donations DROP COLUMN IF EXISTS is_primary_txn;",
        "stop_condition": "If Ed canary changes from 627 txns / $1,318,672.04 → STOP and ROLLBACK.",
        "depends_on": None,
    },

    "phase1_mark_primary": {
        "phase": 1,
        "name": "Mark Primary Transactions",
        "description": """
For each unique transaction (defined by the dedup key), mark exactly
one row as is_primary_txn = true. The dedup key is:

    (name, street_line_1, date_occured, amount,
     candidate_referendum_name, committee_sboe_id)

We keep the row with the LOWEST id as the primary (first loaded).

This is the heaviest query — it touches all 2.4M rows. May take
several minutes. Run it once and verify.

⚠️ REQUIRES ED AUTHORIZATION — this is a bulk UPDATE on raw.ncboe_donations.
""",
        "authorization_required": True,
        "sql": """
-- Mark primary transactions (keep lowest ID per unique transaction)
-- This may take 2-5 minutes on 2.4M rows.
WITH ranked AS (
    SELECT id,
           ROW_NUMBER() OVER (
               PARTITION BY name, street_line_1, date_occured, amount,
                            candidate_referendum_name, committee_sboe_id
               ORDER BY id ASC
           ) AS rn
    FROM raw.ncboe_donations
)
UPDATE raw.ncboe_donations d
SET is_primary_txn = (r.rn = 1)
FROM ranked r
WHERE d.id = r.id;

-- Report results
SELECT
    COUNT(*) as total_rows,
    COUNT(*) FILTER (WHERE is_primary_txn = true) as primary_rows,
    COUNT(*) FILTER (WHERE is_primary_txn = false) as duplicate_rows,
    COUNT(DISTINCT cluster_id) FILTER (WHERE is_primary_txn = true) as primary_clusters,
    ROUND(SUM(norm_amount) FILTER (WHERE is_primary_txn = true)::numeric, 2) as primary_dollars,
    ROUND(SUM(norm_amount)::numeric, 2) as total_dollars
FROM raw.ncboe_donations;
""",
        "expected_output": """
total_rows:       2,431,198
primary_rows:     ~321,756  (±1,000 acceptable)
duplicate_rows:   ~2,109,442
primary_clusters: ~98,305   (±500 acceptable)
primary_dollars:  ~$162,056,814  (±$100,000 acceptable)
total_dollars:    $1,199,211,944.32  (unchanged — we didn't delete anything)
""",
        "canary_check": """
-- Ed canary — deduped values
SELECT COUNT(*) as txns, ROUND(SUM(norm_amount)::numeric, 2) as total
FROM raw.ncboe_donations
WHERE cluster_id = 372171 AND is_primary_txn = true;
-- MUST BE: 147 txns, $332,631.30

-- Ed canary — full values (unchanged)
SELECT COUNT(*) as txns, ROUND(SUM(norm_amount)::numeric, 2) as total
FROM raw.ncboe_donations WHERE cluster_id = 372171;
-- MUST BE: 627 txns, $1,318,672.04  (we didn't delete anything)
""",
        "canary_values": {"deduped_txns": 147, "deduped_total": 332631.30,
                         "full_txns": 627, "full_total": 1318672.04},
        "rollback": "UPDATE raw.ncboe_donations SET is_primary_txn = false;",
        "stop_condition": """
If Ed deduped canary is NOT 147 txns / $332,631.30 → STOP.
If Ed full canary is NOT 627 txns / $1,318,672.04 → STOP and ROLLBACK.
The dedup key may need adjustment — report exact values to Ed.
""",
        "depends_on": "phase1_add_column",
    },

    "phase1_verify": {
        "phase": 1,
        "name": "Verify Transaction Dedup",
        "description": """
Run comprehensive verification of the is_primary_txn marking.
This is a READ-ONLY check — no modifications.
""",
        "authorization_required": False,
        "sql": """
-- 1. Overall summary
SELECT
    COUNT(*) as total_rows,
    COUNT(*) FILTER (WHERE is_primary_txn = true) as primary,
    COUNT(*) FILTER (WHERE is_primary_txn = false) as duplicates,
    ROUND(100.0 * COUNT(*) FILTER (WHERE is_primary_txn = true) / COUNT(*), 1) as primary_pct
FROM raw.ncboe_donations;

-- 2. Source file distribution among primaries vs duplicates
SELECT source_file,
       COUNT(*) FILTER (WHERE is_primary_txn = true) as primary_rows,
       COUNT(*) FILTER (WHERE is_primary_txn = false) as dupe_rows,
       COUNT(*) as total
FROM raw.ncboe_donations
GROUP BY source_file
ORDER BY total DESC;

-- 3. Cluster size distribution (using primary rows only)
WITH cluster_sizes AS (
    SELECT cluster_id, COUNT(*) as txn_count, SUM(norm_amount) as total
    FROM raw.ncboe_donations
    WHERE is_primary_txn = true
    GROUP BY cluster_id
)
SELECT
    CASE
        WHEN txn_count = 1 THEN '1 txn'
        WHEN txn_count BETWEEN 2 AND 5 THEN '2-5 txns'
        WHEN txn_count BETWEEN 6 AND 20 THEN '6-20 txns'
        WHEN txn_count BETWEEN 21 AND 100 THEN '21-100 txns'
        ELSE '100+ txns'
    END as bucket,
    COUNT(*) as clusters,
    SUM(txn_count) as total_txns,
    ROUND(SUM(total)::numeric, 2) as total_dollars
FROM cluster_sizes
GROUP BY 1
ORDER BY MIN(txn_count);

-- 4. Top 10 donors by real (deduped) total
SELECT cluster_id,
       MAX(norm_last) as last_name,
       MAX(norm_first) as first_name,
       COUNT(*) as txns,
       ROUND(SUM(norm_amount)::numeric, 2) as total
FROM raw.ncboe_donations
WHERE is_primary_txn = true
GROUP BY cluster_id
ORDER BY total DESC
LIMIT 10;

-- 5. Ed canary — the ultimate test
SELECT cluster_id,
       COUNT(*) as txns,
       ROUND(SUM(norm_amount)::numeric, 2) as candidate_total
FROM raw.ncboe_donations
WHERE cluster_id = 372171 AND is_primary_txn = true
GROUP BY cluster_id;
-- MUST BE: 147 txns, $332,631.30

-- Party total (unchanged, not affected by spine dedup)
SELECT cluster_id,
       COUNT(*) as txns,
       ROUND(SUM(amount::numeric)::numeric, 2) as party_total
FROM staging.ncboe_party_committee_donations
WHERE cluster_id = 372171
GROUP BY cluster_id;
-- MUST BE: 40 txns, $155,945.45

-- Combined
SELECT
    (SELECT ROUND(SUM(norm_amount)::numeric, 2) FROM raw.ncboe_donations
     WHERE cluster_id = 372171 AND is_primary_txn = true)
    +
    (SELECT ROUND(SUM(amount::numeric)::numeric, 2)
     FROM staging.ncboe_party_committee_donations WHERE cluster_id = 372171)
    AS ed_combined_total;
-- MUST BE: $488,576.75
""",
        "expected_output": """
Ed candidate: 147 txns, $332,631.30
Ed party:     40 txns, $155,945.45
Ed combined:  $488,576.75
All source files should have primary_rows > 0
Top 10 donors should look like real NC Republican donors, not nonsense
""",
        "canary_check": "Embedded in the SQL above",
        "canary_values": {"ed_combined": 488576.75},
        "rollback": "N/A — read-only verification",
        "stop_condition": "If Ed combined ≠ $488,576.75 → Phase 1 marking is wrong. Re-investigate dedup key.",
        "depends_on": "phase1_mark_primary",
    },

    # ── PHASE 4: Populate contribution_map ──

    "phase4_contribution_map": {
        "phase": 4,
        "name": "Populate contribution_map",
        "description": """
Insert all primary candidate donations and all linked party donations
into donor_intelligence.contribution_map. Uses ONLY is_primary_txn = true
rows from the spine to avoid inflated counts.

⚠️ This TRUNCATEs the contribution_map table first.
""",
        "authorization_required": True,
        "sql": """
-- Clear existing (if any)
TRUNCATE donor_intelligence.contribution_map;

-- Insert CANDIDATE donations (primary transactions only)
INSERT INTO donor_intelligence.contribution_map (
    person_id, source_system, source_row_id, amount, donation_date,
    committee_id, committee_name, candidate_name, match_method, match_confidence
)
SELECT
    d.cluster_id,
    'ncboe_candidate',
    d.id,
    d.norm_amount,
    d.norm_date,
    d.committee_sboe_id,
    d.committee_name,
    d.candidate_referendum_name,
    'spine_cluster',
    1.0
FROM raw.ncboe_donations d
WHERE d.cluster_id IS NOT NULL
  AND d.norm_amount IS NOT NULL
  AND d.is_primary_txn = true;

-- Insert PARTY donations (all linked — no dedup issue in party table)
INSERT INTO donor_intelligence.contribution_map (
    person_id, source_system, source_row_id, amount, donation_date,
    committee_id, committee_name, match_method, match_confidence
)
SELECT
    p.cluster_id,
    'ncboe_party',
    p.id,
    p.amount::numeric,
    p.norm_date,
    p.committee_sboe_id,
    p.committee_name,
    'party_match_v1',
    0.97
FROM staging.ncboe_party_committee_donations p
WHERE p.cluster_id IS NOT NULL
  AND p.amount IS NOT NULL;

-- Verify
SELECT source_system,
       COUNT(*) AS rows,
       ROUND(SUM(amount)::numeric, 2) AS total_dollars,
       COUNT(DISTINCT person_id) AS unique_donors
FROM donor_intelligence.contribution_map
GROUP BY source_system;

-- Ed canary
SELECT SUM(amount) AS ed_combined_total
FROM donor_intelligence.contribution_map
WHERE person_id = 372171;
-- MUST BE: $488,576.75
""",
        "expected_output": """
ncboe_candidate: ~321,756 rows, ~$162M, ~98K unique donors
ncboe_party:     ~288,786 rows (linked party donations)
Ed combined:     $488,576.75
""",
        "canary_check": """
SELECT SUM(amount) FROM donor_intelligence.contribution_map WHERE person_id = 372171;
-- MUST BE: $488,576.75
""",
        "canary_values": {"ed_combined": 488576.75},
        "rollback": "TRUNCATE donor_intelligence.contribution_map;",
        "stop_condition": "If Ed combined ≠ $488,576.75 → contribution_map is wrong. TRUNCATE and investigate.",
        "depends_on": "phase1_verify",
    },

    # ── PHASE 5: Populate person_master ──

    "phase5_person_master": {
        "phase": 5,
        "name": "Populate person_master",
        "description": """
One row per cluster with correct (non-inflated) totals from contribution_map.
Uses the most common first name variant, DataTrust reg_zip5 for authoritative zip,
and includes all contact info with source provenance.

⚠️ This TRUNCATEs person_master first.
⚠️ The person_master INSERT is complex — Cursor should review the SQL
    carefully and test on Ed's cluster first before running the full insert.
""",
        "authorization_required": True,
        "sql": """
-- This is a TEMPLATE — Cursor should adapt to the actual person_master schema.
-- The key principle: all dollar totals come from contribution_map (already deduped).
-- All contact/identity info comes from the spine (using any row in the cluster,
-- preferring the primary transaction row).

-- Step 1: Test on Ed's cluster first
SELECT
    d.cluster_id as person_id,
    MODE() WITHIN GROUP (ORDER BY d.norm_first) as first_name,  -- most common first name
    MAX(d.norm_middle) as middle_name,
    MAX(d.norm_last) as last_name,
    MAX(d.norm_suffix) as suffix,
    MAX(d.city) as city,
    'NC' as state,
    -- Use DataTrust reg_zip5 as authoritative (Ed = 27104 not 27105)
    COALESCE(
        (SELECT v.reg_zip5 FROM core.datatrust_voter_nc v
         WHERE v.rnc_regid = MAX(d.rnc_regid) LIMIT 1),
        MAX(d.norm_zip5)
    ) as zip5,
    MAX(d.cell_phone) as cell_phone,
    MAX(d.home_phone) as home_phone,
    MAX(d.personal_email) as personal_email,
    MAX(d.business_email) as business_email,
    MAX(d.norm_employer) as employer,
    MAX(d.rnc_regid) as rnc_regid,
    cm.total_amount as donations_total,
    cm.txn_count as donation_count,
    cm.first_date as first_donation_date,
    cm.last_date as last_donation_date,
    cm.has_party,
    cm.has_candidate
FROM raw.ncboe_donations d
JOIN (
    SELECT person_id,
           ROUND(SUM(amount)::numeric, 2) as total_amount,
           COUNT(*) as txn_count,
           MIN(donation_date) as first_date,
           MAX(donation_date) as last_date,
           BOOL_OR(source_system = 'ncboe_party') as has_party,
           BOOL_OR(source_system = 'ncboe_candidate') as has_candidate
    FROM donor_intelligence.contribution_map
    GROUP BY person_id
) cm ON cm.person_id = d.cluster_id
WHERE d.cluster_id = 372171  -- TEST ON ED FIRST
GROUP BY d.cluster_id, cm.total_amount, cm.txn_count, cm.first_date,
         cm.last_date, cm.has_party, cm.has_candidate;

-- Expected for Ed:
-- donations_total = $488,576.75
-- zip5 = 27104
-- cell_phone = 3369721000
-- personal_email = ed@broyhill.net
-- business_email = jim@broyhill.net
""",
        "expected_output": """
Ed test row:
  person_id: 372171
  first_name: ED (most common variant)
  last_name: BROYHILL
  zip5: 27104 (from DataTrust, NOT 27105)
  donations_total: $488,576.75
  cell_phone: 3369721000
  personal_email: ed@broyhill.net
  NO jsneeden@msn.com anywhere
""",
        "canary_check": """
-- After full insert:
SELECT person_id, first_name, last_name, zip5, donations_total,
       cell_phone, personal_email, business_email
FROM donor_intelligence.person_master WHERE person_id = 372171;
""",
        "canary_values": {"zip5": "27104", "total": 488576.75, "email": "ed@broyhill.net"},
        "rollback": "TRUNCATE donor_intelligence.person_master;",
        "stop_condition": "If Ed's zip5 = 27105 → STOP, fix the zip derivation. If jsneeden@msn.com appears → STOP, clear it.",
        "depends_on": "phase4_contribution_map",
    },
}


# ════════════════════════════════════════════════════════════════════════════
# TASK FILE GENERATOR
# ════════════════════════════════════════════════════════════════════════════

def get_next_task_number():
    """Get the next sequential task number."""
    os.makedirs(TASK_DIR, exist_ok=True)
    existing = [f for f in os.listdir(TASK_DIR) if f.startswith("TASK_") and f.endswith(".md")]
    if not existing:
        return 1
    numbers = [int(f.split("_")[1].split(".")[0]) for f in existing]
    return max(numbers) + 1


def determine_next_task():
    """Based on database state, determine what task should run next."""
    try:
        conn = psycopg2.connect(DB_CONN)
        cur = conn.cursor()

        # Check: does is_primary_txn exist?
        cur.execute("""
            SELECT COUNT(*) FROM information_schema.columns
            WHERE table_schema = 'raw' AND table_name = 'ncboe_donations'
            AND column_name = 'is_primary_txn'
        """)
        has_col = cur.fetchone()[0] > 0

        if not has_col:
            cur.close(); conn.close()
            return "phase1_add_column"

        # Check: is it populated?
        cur.execute("SELECT COUNT(*) FROM raw.ncboe_donations WHERE is_primary_txn = true")
        primary_count = cur.fetchone()[0]

        if primary_count == 0:
            cur.close(); conn.close()
            return "phase1_mark_primary"

        # Check: has it been verified? (look for result file)
        if not os.path.exists(os.path.join(RESULT_DIR, "phase1_verify_DONE")):
            cur.close(); conn.close()
            return "phase1_verify"

        # Check: contribution_map
        try:
            cur.execute("SELECT COUNT(*) FROM donor_intelligence.contribution_map")
            cm_count = cur.fetchone()[0]
        except psycopg2.Error:
            cm_count = 0
            conn.rollback()

        if cm_count == 0:
            cur.close(); conn.close()
            return "phase4_contribution_map"

        # Check: person_master
        try:
            cur.execute("SELECT COUNT(*) FROM donor_intelligence.person_master")
            pm_count = cur.fetchone()[0]
        except psycopg2.Error:
            pm_count = 0
            conn.rollback()

        if pm_count == 0:
            cur.close(); conn.close()
            return "phase5_person_master"

        cur.close(); conn.close()
        return None  # All phases complete

    except Exception as e:
        return f"ERROR determining next task: {e}"


def generate_task_file(task_id, task_number=None):
    """Generate a task file for Cursor."""
    if task_id not in TASK_REGISTRY:
        print(f"ERROR: Unknown task '{task_id}'. Use --list to see available tasks.")
        return None

    task = TASK_REGISTRY[task_id]
    if task_number is None:
        task_number = get_next_task_number()

    os.makedirs(TASK_DIR, exist_ok=True)
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    filename = f"TASK_{task_number:03d}_{task_id}.md"
    filepath = os.path.join(TASK_DIR, filename)

    auth_warning = ""
    if task.get("authorization_required"):
        auth_warning = """
## ⚠️ AUTHORIZATION REQUIRED

This task modifies raw.ncboe_donations. Ed must type exactly:
    "I AUTHORIZE THIS ACTION"
before you execute the SQL below.

Show Ed this task file. Wait for authorization. Do not proceed without it.
"""

    content = f"""# CURSOR TASK {task_number:03d} — {task['name']}
## Generated: {now}
## Phase: {task['phase']}
## Task ID: {task_id}
## Depends on: {task.get('depends_on', 'None')}

---
{auth_warning}
## DESCRIPTION

{task['description']}

---

## SQL TO EXECUTE

```sql
{task['sql']}
```

---

## EXPECTED OUTPUT

{task['expected_output']}

---

## CANARY CHECK (run after SQL)

```sql
{task['canary_check']}
```

Expected canary values: {json.dumps(task.get('canary_values', {}), indent=2)}

---

## STOP CONDITION

{task['stop_condition']}

---

## ROLLBACK (if something goes wrong)

```sql
{task['rollback']}
```

---

## RESULT INSTRUCTIONS

After executing, create a result file at:
    /tools/cursor_results/RESULT_{task_number:03d}_{task_id}.md

Include:
1. Exact output of each query
2. Canary check results
3. PASS or FAIL
4. Any errors or unexpected behavior
5. Timestamp

Or run:
    python3 /tools/cursor_command_brief.py --result {task_id} --status pass --output "paste output here"
"""

    with open(filepath, 'w') as f:
        f.write(content)

    # Log the task
    log_entry = {
        "task_number": task_number,
        "task_id": task_id,
        "generated_at": now,
        "status": "pending",
        "authorization_required": task.get("authorization_required", False),
    }
    append_to_log(log_entry)

    return filepath


def record_result(task_id, status, output):
    """Record a task result."""
    os.makedirs(RESULT_DIR, exist_ok=True)
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    # Find the task number from log
    log = load_log()
    task_entry = None
    for entry in reversed(log):
        if entry.get("task_id") == task_id:
            task_entry = entry
            break

    task_number = task_entry["task_number"] if task_entry else 0

    filename = f"RESULT_{task_number:03d}_{task_id}.md"
    filepath = os.path.join(RESULT_DIR, filename)

    content = f"""# RESULT — {task_id}
## Completed: {now}
## Status: {status.upper()}

### Output:
{output}
"""

    with open(filepath, 'w') as f:
        f.write(content)

    # Update log
    if task_entry:
        task_entry["status"] = status
        task_entry["completed_at"] = now
        task_entry["output_summary"] = output[:500]
        save_log(log)

    # If this was phase1_verify and it passed, create the marker
    if task_id == "phase1_verify" and status.lower() == "pass":
        marker = os.path.join(RESULT_DIR, "phase1_verify_DONE")
        with open(marker, 'w') as f:
            f.write(now)

    print(f"Result recorded: {filepath}")
    return filepath


# ════════════════════════════════════════════════════════════════════════════
# AUDIT LOG
# ════════════════════════════════════════════════════════════════════════════

def load_log():
    if os.path.exists(LOG_FILE):
        with open(LOG_FILE, 'r') as f:
            return json.load(f)
    return []

def save_log(log):
    with open(LOG_FILE, 'w') as f:
        json.dump(log, f, indent=2)

def append_to_log(entry):
    log = load_log()
    log.append(entry)
    save_log(log)


# ════════════════════════════════════════════════════════════════════════════
# CLI
# ════════════════════════════════════════════════════════════════════════════

def main():
    parser = argparse.ArgumentParser(description="Cursor Command Brief Generator")
    parser.add_argument("--generate", action="store_true",
                       help="Auto-detect next task and generate it")
    parser.add_argument("--task", type=str,
                       help="Generate a specific task by ID")
    parser.add_argument("--list", action="store_true",
                       help="List all available tasks")
    parser.add_argument("--result", type=str,
                       help="Record a result for a task ID")
    parser.add_argument("--status", type=str, choices=["pass", "fail"],
                       help="Result status (use with --result)")
    parser.add_argument("--output", type=str,
                       help="Result output text (use with --result)")
    parser.add_argument("--log", action="store_true",
                       help="Show the task audit log")

    args = parser.parse_args()

    if args.list:
        print("\nAvailable tasks:")
        print(f"{'ID':30s} {'Phase':6s} {'Name':40s} {'Depends On'}")
        print("-" * 100)
        for tid, task in TASK_REGISTRY.items():
            auth = " ⚠️AUTH" if task.get("authorization_required") else ""
            print(f"{tid:30s} {task['phase']:<6d} {task['name']:40s} {task.get('depends_on', '—')}{auth}")
        return 0

    if args.log:
        log = load_log()
        if not log:
            print("No tasks in the log yet.")
            return 0
        print("\nTask Audit Log:")
        for entry in log:
            print(f"  #{entry['task_number']:03d} {entry['task_id']:30s} "
                  f"status={entry.get('status', 'pending'):6s} "
                  f"generated={entry['generated_at']}")
        return 0

    if args.result:
        if not args.status:
            print("ERROR: --status required with --result")
            return 1
        filepath = record_result(args.result, args.status, args.output or "No output provided")
        return 0

    if args.generate:
        next_task = determine_next_task()
        if next_task is None:
            print("\n✓ All registered phases complete. No more tasks to generate.")
            print("  Review REVISED_PLAN_APR15.md for remaining work (employer bridge, committees, etc.)")
            return 0
        if next_task.startswith("ERROR"):
            print(f"\n✗ {next_task}")
            return 1
        print(f"\nNext task: {next_task}")
        filepath = generate_task_file(next_task)
        if filepath:
            print(f"Generated: {filepath}")
            print(f"\nCursor: read {filepath} and execute.")
        return 0

    if args.task:
        filepath = generate_task_file(args.task)
        if filepath:
            print(f"Generated: {filepath}")
        return 0

    # Default: show status
    next_task = determine_next_task()
    print("\nCursor Command Brief Generator — Status")
    print("=" * 50)
    if next_task is None:
        print("All registered phases complete.")
    elif next_task.startswith("ERROR"):
        print(f"Error: {next_task}")
    else:
        print(f"Next task: {next_task}")
        print(f"  Phase: {TASK_REGISTRY[next_task]['phase']}")
        print(f"  Name:  {TASK_REGISTRY[next_task]['name']}")
        auth = TASK_REGISTRY[next_task].get("authorization_required", False)
        if auth:
            print(f"  ⚠️  Requires Ed's authorization")
        print(f"\nRun with --generate to create the task file.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
