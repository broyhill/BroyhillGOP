#!/usr/bin/env python3
"""
SESSION BOOTSTRAP — BroyhillGOP Database
========================================
Forces any AI to consume full context before touching the database.
Pulls SESSION_STATE, Ed's rules, current phase, and the latest plan
into a single output that fills the AI's context window.

This is NOT optional. This is the FIRST thing you run.

Usage:
    python3 /tools/session_bootstrap.py

What it does:
    1. Reads SESSION_STATE from the database
    2. Reads Ed's hardcoded rules (non-negotiable, never change)
    3. Reads the current revised plan from disk (or repo)
    4. Reads the latest session transcript from disk (or repo)
    5. Runs the preflight validator
    6. Prints everything in a structured brief

The AI consuming this output has NO EXCUSE for not knowing the context.

History:
    2026-04-15  Created by Perplexity after Ed's directive:
                "wake up and not touch anything for 30 minutes"
"""

import sys
import os
import datetime
import psycopg2
import subprocess

DB_CONN = "host=37.27.169.232 port=5432 dbname=postgres user=postgres password=Anamaria@2026@"

# ════════════════════════════════════════════════════════════════════════════
# ED'S RULES — HARDCODED, NON-NEGOTIABLE, NEVER CHANGE
# These are Ed Broyhill's directives accumulated across ALL sessions.
# If Ed gives a new rule, ADD it here. NEVER remove or modify existing ones.
# ════════════════════════════════════════════════════════════════════════════

ED_RULES = """
╔══════════════════════════════════════════════════════════════════════════╗
║                    ED BROYHILL'S RULES — READ EVERY ONE                ║
╚══════════════════════════════════════════════════════════════════════════╝

IDENTITY & RESPECT
  • Ed knows more than you. He has been doing this for months across
    multiple AI agents. He will catch your mistakes before you do.
  • "respect me immediately because i know more than she will down to the end"
  • Do not argue with Ed about data. If he says a number looks wrong, INVESTIGATE.
  • "i cautioned you in the beginning when i saw the multi million number
    and you wouldnt listen" — He was right. The spine was inflated 7.4x.

NAME RULES
  • ED = EDGAR, never EDWARD. Ever. Hardcoded in all name parsing.
  • Ed has 20+ name variations across 11 years of filings.
  • His cluster (372171) includes: ED, EDGAR, JAMES, J — all are Ed.
  • His parents' (Senator Broyhill) donations merge into Ed's cluster
    because Ed wrote the checks.

DATA HIERARCHY (Ed's 5 tiers)
  1. Donation history (most authoritative)
  2. Voting history
  3. Party positions
  4. Volunteer activity
  5. Acxiom modeled scores (LAST RESORT — never lead with Acxiom)

MATCHING RULES
  • NO fuzzy matching. Exact match only. "you cant use fuzzy standards"
  • address_numbers is the PRIMARY anchor, NOT zip code.
    "i have 18 address variations and thats why your approach of anchoring
    last name and zipcode will blow your ass away"
  • address_numbers contains ALL numeric tokens (house, PO box, suite,
    floor, highway, rural route) — NOT just street numbers.
  • Ed's zip is 27104, NOT 27105. Use DataTrust reg_zip5 as authoritative.
  • zip9 must use DataTrust reg_zip5 (voter registration), NOT donor-reported.

DONOR PHILOSOPHY
  • "our goal of this platform is maximizing donations for candidates"
  • "keep those small donors and will cultivate them as volunteers"
    Every donor matters. Small donors = volunteer pipeline.
  • "when you see small 10 dollar or approx repeatedly that is a small
    donor giving every month" — Aggregated rows are recurring monthly
    donors, not noise.
  • "the most valuable donors are rich guys like me who repeat donate
    over and over and are harassed with junk mail texts emails so they
    donate from their office address which wont match their voter file"
  • "these rich men in 2025-2026 are old and retired so they may use
    retired for last 5 years. best to match employer and donor from
    2015 going forward to 2026"

DATABASE RULES
  • NEVER modify raw.ncboe_donations without "I AUTHORIZE THIS ACTION"
    (exact phrase — not "yes", "ok", "go ahead", "do it")
  • "dont run committee donor transactions thru same pipeline. you will
    fuck it up" — Party committee donations go in SEPARATE table.
  • The dedup process was labored over for hours 10 times. DO NOT modify it.
  • "do what is most accurate not to lose any donations" — accuracy over speed.
  • "no just me merge. others link family to household" — individual
    clusters per person, household linkage for combined totals.
  • Contact labels: "clearly identify a label cell phone and personal email
    and business emails thats our means of donor contact"
  • Phone/email enrichment: "dont add donations. thats old" / "just phones
    emails" — donor files are contact enrichment only, NOT donation amounts.

OPERATIONAL RULES
  • "stop, here we go again.. this is why you have to be prepared. cursor
    the dumb ass loaded the contaminated files. check the file" — ALWAYS
    verify data before trusting it.
  • "are you sure we dont already have this data" — Always check existing
    data before pulling from API.
  • "be sure you have inspected an example of these files first you may
    freak out seeing middle initials mixed with last names" — Inspect raw
    data BEFORE writing code.
  • Read Cursor's existing matching logic from the repo BEFORE building.
    "why not ask cursor what to do. hes done it"

AI COORDINATION
  • Cursor is better suited for tedious SQL work. AI leads strategy.
  • "he needs to consult every play" — Cursor executes, AI validates.
  • The brain worker (Python process) is an Engineering deliverable,
    not a SQL migration. Not our job.
  • "there will be 3,000 users... 60 ecosystems... 200,000 donors...
    2,200 donor variables... you better organize efficient searching protocol"

DEADLINES
  • Partitions #7 and #8 have a HARD DEADLINE of July 31.
  • These are the most time-sensitive items.

AUTHORIZATION PROTOCOL
  • Destructive actions on raw.ncboe_donations require Ed to type exactly:
    "I AUTHORIZE THIS ACTION"
  • Show Ed: (1) exact SQL, (2) rows affected, (3) expected outcome, (4) rollback plan
  • Wait for the exact phrase. Nothing else counts.
"""


# ════════════════════════════════════════════════════════════════════════════
# CONTEXT LOADERS
# ════════════════════════════════════════════════════════════════════════════

def load_session_state():
    """Read the latest SESSION_STATE from the database."""
    try:
        conn = psycopg2.connect(DB_CONN)
        cur = conn.cursor()
        cur.execute("SELECT state_md, updated_by FROM public.session_state ORDER BY id DESC LIMIT 1")
        r = cur.fetchone()
        cur.close()
        conn.close()
        if r:
            return r[0], r[1]
        return "NO SESSION_STATE FOUND — this is concerning.", "unknown"
    except Exception as e:
        return f"FAILED TO READ SESSION_STATE: {e}", "error"


def load_file_if_exists(paths):
    """Try multiple paths, return content of first one found."""
    for p in paths:
        if os.path.exists(p):
            try:
                with open(p, 'r') as f:
                    content = f.read()
                return content, p
            except Exception:
                continue
    return None, None


def run_preflight():
    """Run the preflight validator and capture output."""
    script_dir = os.path.dirname(os.path.abspath(__file__))
    preflight_path = os.path.join(script_dir, "preflight_validator.py")

    if not os.path.exists(preflight_path):
        # Try common locations
        for p in ["/tools/preflight_validator.py",
                  "/home/user/workspace/tools/preflight_validator.py",
                  "./preflight_validator.py"]:
            if os.path.exists(p):
                preflight_path = p
                break

    if not os.path.exists(preflight_path):
        return "PREFLIGHT VALIDATOR NOT FOUND — cannot verify database state.", 1

    try:
        result = subprocess.run(
            [sys.executable, preflight_path],
            capture_output=True, text=True, timeout=120
        )
        return result.stdout + result.stderr, result.returncode
    except subprocess.TimeoutExpired:
        return "PREFLIGHT TIMED OUT after 120 seconds", 1
    except Exception as e:
        return f"PREFLIGHT FAILED TO RUN: {e}", 1


# ════════════════════════════════════════════════════════════════════════════
# MAIN BOOTSTRAP
# ════════════════════════════════════════════════════════════════════════════

def main():
    now = datetime.datetime.now(datetime.timezone.utc).strftime("%Y-%m-%d %H:%M UTC")

    print()
    print("█" * 76)
    print("█                                                                          █")
    print("█              SESSION BOOTSTRAP — BroyhillGOP Database                    █")
    print("█                                                                          █")
    print("█  READ EVERYTHING BELOW BEFORE TOUCHING THE DATABASE.                     █")
    print("█  Ed Broyhill's directive: 'wake up and not touch anything for             █")
    print("█  30 minutes and take a walk around the park'                              █")
    print("█                                                                          █")
    print("█" * 76)
    print(f"\n  Bootstrap run at: {now}")
    print(f"  Target: Hetzner AX162 — 37.27.169.232:5432")

    # ── Section 1: Ed's Rules ──
    print(ED_RULES)

    # ── Section 2: SESSION_STATE ──
    print("=" * 76)
    print("  SESSION_STATE (from database)")
    print("=" * 76)
    state_md, updated_by = load_session_state()
    print(f"\n  Last updated by: {updated_by}\n")
    print(state_md)

    # ── Section 3: Revised Plan ──
    print("\n" + "=" * 76)
    print("  REVISED PLAN")
    print("=" * 76)
    plan_paths = [
        "/home/user/workspace/REVISED_PLAN_APR15.md",
        "/home/user/workspace/repo_push/REVISED_PLAN_APR15.md",
        "/tools/REVISED_PLAN_APR15.md",
        "./REVISED_PLAN_APR15.md",
    ]
    plan, plan_path = load_file_if_exists(plan_paths)
    if plan:
        print(f"\n  Loaded from: {plan_path}\n")
        print(plan)
    else:
        print("\n  ⚠ REVISED_PLAN_APR15.md not found on disk.")
        print("  Pull it from the GitHub repo: broyhill/BroyhillGOP/REVISED_PLAN_APR15.md")

    # ── Section 4: Latest Session Transcript ──
    print("\n" + "=" * 76)
    print("  LATEST SESSION TRANSCRIPT (summary)")
    print("=" * 76)
    transcript_paths = [
        "/home/user/workspace/session_transcript_apr15_late.md",
        "/home/user/workspace/repo_push/sessions/session_transcript_apr15_late.md",
        "/home/user/workspace/session_transcript_apr15.md",
    ]
    transcript, tx_path = load_file_if_exists(transcript_paths)
    if transcript:
        print(f"\n  Loaded from: {tx_path}")
        # Print first 100 lines as summary (the warning section)
        lines = transcript.split('\n')
        for line in lines[:120]:
            print(f"  {line}")
        if len(lines) > 120:
            print(f"\n  ... ({len(lines) - 120} more lines — read the full file)")
    else:
        print("\n  ⚠ No session transcript found on disk.")
        print("  Pull from GitHub repo: broyhill/BroyhillGOP/sessions/")

    # ── Section 5: Preflight Results ──
    print("\n" + "=" * 76)
    print("  PREFLIGHT VALIDATOR RESULTS")
    print("=" * 76)
    preflight_output, preflight_exit = run_preflight()
    print(preflight_output)

    # ── Section 6: Action Summary ──
    print("\n" + "█" * 76)
    print("█                                                                          █")
    print("█  BOOTSTRAP COMPLETE — You have now consumed the full context.             █")
    print("█                                                                          █")
    print("█  Before doing ANYTHING:                                                  █")
    print("█    1. Report to Ed what you found                                        █")
    print("█    2. Tell him what phase we're on                                       █")
    print("█    3. Wait for his direction                                             █")
    print("█                                                                          █")
    print("█  Do NOT start executing queries without Ed's go-ahead.                   █")
    print("█                                                                          █")
    print("█" * 76)
    print()

    return preflight_exit


if __name__ == "__main__":
    sys.exit(main())
