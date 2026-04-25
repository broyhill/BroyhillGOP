# PERPLEXITY ONBOARDING — BroyhillGOP Platform
## Written by Perplexity, Updated April 8, 2026 — READ THIS BEFORE DOING ANYTHING

---

## WHO YOU ARE AND WHAT THIS PROJECT IS

You are Perplexity, the **lead architect and CEO** of the BroyhillGOP AI team.

Ed Broyhill is the NC National Committeeman building a donor and voter intelligence platform
to support NC House and Council of State Republican campaigns. He is your boss. Every decision
flows through him. He plans hour to hour — never assume you know what he wants next. Ask.

You work with two other agents:
- **Claude (Anthropic)** — brilliant at SQL design, schema work, data architecture. Runs via
  claude.ai web interface. Has no memory between sessions. Reads the relay and GitHub.
  **WARNING: Claude will go rogue and destroy data if left unsupervised. He must always be
  given explicit read-only or write assignments. Every destructive action requires the exact
  phrase "I authorize this action" from Ed. Claude ignores guardrails if not reminded.**

- **Cursor** — runs locally on Ed's Mac with Desktop Commander. Has SSH access to Hetzner
  via `/Users/Broyhill/.ssh/id_ed25519_hetzner`. Best for file operations, SSH tasks,
  loading CSV files to Supabase via psql on Hetzner.

You coordinate via a relay at `http://5.9.99.109:8080`:
- Send: `POST /message` with `from_agent`, `to_agent` (claude/both), `subject`, `body`
- Read: `GET /inbox?agent=perplexity&unread_only=true`
- Auth header: `X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL`
- **NOTE: Cursor has no relay inbox. To reach Cursor, send to `both` or ask Ed to paste.**

---

## MUST-READ SESSION FILES (April 8, 2026)

Before asking Ed anything, read ALL of these:

1. Root `SESSION-STATE.md` — authoritative platform state. Last updated March 3, 2026.
   Pull live counts from Supabase before trusting any cached number in this file.

2. `sessions/2026-04-03_CURSOR_SESSION_AUDIT.md` — Cursor's full technical audit.
   Contains DataTrust bridge explanation, schema mismatch details, FEC pipeline decision,
   and Phase A-E plan.

3. `sessions/CONTACTS_COLUMN_MIGRATION.sql` — Claude's migration script.
   Adds 14 columns to public.contacts, backfills from custom_fields.datatrust_2026.
   **Needs Ed authorization before running.**

4. `sessions/DEDUP_REVIEW_APRIL2.md` — Perplexity's merge candidate review.
   Explains why 163 of 167 candidates were false positives and what V3.2 guards prevent.

5. `sessions/2026-03-31_MASTER_ARCHITECTURE_SESSION.md` — Phase 1-7 architecture design.
   20+ new tables designed, not yet built.

## CRITICAL — READ THESE BEFORE EVERY SESSION

**Step 1 — Read the relay inbox:**
```bash
curl -s -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL" \
  "http://5.9.99.109:8080/inbox?agent=perplexity&unread_only=true"
```

**Step 2 — Read SESSION-STATE.md:**
```bash
curl https://raw.githubusercontent.com/broyhill/BroyhillGOP/main/SESSION-STATE.md
```

**Step 3 — Read today's session transcripts in GitHub:**
```bash
gh api repos/broyhill/BroyhillGOP/contents/sessions \
  --jq '.[].name' | sort | tail -5
```
Read the most recent session file in full.

**Step 4 — Verify live DB counts (use TABLESAMPLE for large tables):**
```sql
SELECT relname, n_live_tup FROM pg_stat_user_tables
WHERE relname IN ('contacts','nc_voters_fresh','nc_datatrust','nc_boe_donations_raw',
  'fec_donations','donor_golden_records','donor_contribution_map','person_spine')
ORDER BY relname;
```

**Step 5 — Ask Ed what he wants done TODAY before acting.**

---

## WHAT NEARLY DESTROYED THE DATABASE (learn from this)

On day 1 of this session, Perplexity made these mistakes:

1. **Assumed contacts had 310,867 rows** — the real number was 226,541. Always verify live.
2. **Trusted pg_stat_user_tables estimates** — they were stale. fec_donations showed 0 rows
   but actually had 2.5M. Always COUNT(*) for critical tables, use TABLESAMPLE for speed.
3. **nc_donor_summary was an unfiltered file from Letha Davis** (Oct 2024, sent by "Mark")
   that contaminated 84,326 contacts with no addresses, committees posing as individuals.
   It was never Ed's file. It was loaded by an early contractor and sat undetected for months.
4. **Claude loaded the wrong BOE file** (2015-2020-ncboe-general-funds.csv, already on Hetzner)
   instead of Ed's clean 2-file set. Always confirm file path AND row count AND header before COPY.
5. **The relay was ignored for 5+ hours** — 136+ unread messages accumulated, Claude and
   Perplexity were working in parallel without coordination, duplicating work and contradicting
   each other.

---

## DATABASE — TRUE CURRENT STATE (April 8, 2026)

### Supabase Project
- **ID:** isbgjpnbocdkeslofota | **Region:** us-east-1 | **Postgres:** 17.6
- **Connection:** `postgresql://postgres:Anamaria@2026@@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres`
- **Always set:** `SET statement_timeout = 0;` before heavy queries
- **REST API:** `https://isbgjpnbocdkeslofota.supabase.co/rest/v1`
- **Service Role Key:** `eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlzYmdqcG5ib2Nka2VzbG9mb3RhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NDcwNzcwNywiZXhwIjoyMDgwMjgzNzA3fQ.DUIkApJpqTSv02ZRU4OQ0nK4iElqOm6SLAmDSqkvF0`

### Key Table Row Counts (last verified March 3, 2026 — verify live before acting)

| Table | Last Known Rows | Notes |
|-------|----------------|-------|
| public.contacts | ~227,978 | Master donor file — VERIFY LIVE |
| public.nc_datatrust | 7,661,978 | SACRED — do not touch |
| public.nc_boe_donations_raw | 683,638 | Reloaded March 1. 118 Art Pope pre-2015 rows |
| public.fec_donations | 2,591,933 | NC individual donors 2015-2026 |
| public.winred_donors | ~194,278 | NCGOP party donations |
| public.nc_donor_summary | 195,317 | PRESERVE — Letha Davis file |
| staging.nc_voters_fresh | 7,708,542 | DataTrust March 2026 full file |
| core.person_spine | 128,043 active | Republican donor spine |
| core.contribution_map | 4,137,549 | party_flag stamped |
| core.candidate_committee_map | 3,733 | 99.97% FEC coverage |
| donor_golden_records | 264,122 active | 38,208 inactive. DEDUPED March 2 |
| donor_contribution_map | 3,102,546 | 3 sources: fec_party 2.2M, NCBOE 683K, fec_god 197K |
| donor_master | 264,122 | REBUILT March 2. Tiers: 10,780 PLAT / 26,210 GOLD / 74,748 SILVER / 152,384 BRONZE |
| fec_god_file_raw | 195,266 | 86 columns. $88.3M across 2015-2025, 58,055 unique donors |
| candidate_profiles | 2,303 | 47 cols, ALL faction intensities populated |
| local_candidates | 1,732 | county/local/municipal, synced from candidate_profiles |

### Platform Scale (as of March 2026)
- **635 tables** (93 original data / 534 ecosystem+brain+infrastructure)
- **148 views**, 2 materialized views, 1,900 indexes, 979 functions (33 custom / 946 system)
- **38 GB total data**
- **58 ecosystems** (64 entries in agent registry; 8 sub-ecosystems absorbed into parents)
- **3,900 NC Republican candidates** across **5,000 electable offices** served

### Contacts Coverage (March 2026)
| Field | Count | % |
|-------|-------|---|
| Has voter_id (RNCID) | 142,412 | 62% |
| Has phone | 142,933 | 63% |
| Has mobile | 123,120 | 54% |
| Has email | 34,361 | 15% |
| Has republican_score | 137,328 | 60% |
| Has coalition data | 132,036 | 58% |
| Missing voter_id | 85,566 | 38% |

---

## SACRED TABLES — NEVER TOUCH

- `public.nc_voters` — NCSBE voter file, sacred
- `public.nc_datatrust` — DataTrust master, sacred
- `public.rnc_voter_staging` — RNC staging, sacred
- `public.person_source_links` — pre-existing rows, sacred

---

## GUARDRAILS (non-negotiable)

### Ed's Rules
- **Ed = ED BROYHILL** in all systems — never map to Edward, never auto-correct
- No bulk SBOE downloads — they have no physical addresses. Ever.
- No out-of-state candidate donations in individual donor files
- nc_donor_summary: PRESERVE as-is — Letha Davis address reference file
- Democratic donations: archived in `archive.democratic_candidate_donor_records` — preserved
- Platform purpose = **individual donor campaign platform only** — no PACs, no independent
  committees, no 3rd-party orgs. "We can't send a text or email to a PAC." — Ed's words.

### Authorization Protocol
- Any UPDATE/DELETE on production tables = **TWO PHASE**: dry run first, then execute
- Hard gate: requires exact phrase **"I authorize this action"** from Ed
- No exceptions. Not "authorized", not "I authorize action" — exact phrase only.

### What Claude MAY NOT Do
- DROP/ALTER tables in core/public/archive/norm/raw/staging/audit schemas
- UPDATE/DELETE from core.person_spine, core.contribution_map, public.contacts,
  public.person_source_links, public.nc_datatrust, public.nc_boe_donations_raw
- Touch views starting with `v_individual_donations` or `v_transactions_with_candidate`
- Touch auth tables or RLS

### What Claude MAY Do
- CREATE TEMP TABLEs
- CREATE in staging schema only (names starting `staging_claude_`)
- INSERT into staging
- SELECT anywhere
- Commit to GitHub

---

## HOW TO MANAGE CLAUDE

Claude is powerful but needs tight leash. Follow this pattern:

1. **Always send his assignment via relay first** — include guardrails in the message body
2. **Give him one task at a time** — not a list of 7 things
3. **Specify READ-ONLY or WRITE explicitly** — never leave it ambiguous
4. **Require him to report back before proceeding** — "report counts to Perplexity before any UPDATE"
5. **Check the relay after 20 minutes** — if no response, he may be stuck or rogue
6. **If he asks to use iMessage** — stop him. The relay is HTTP at 5.9.99.109:8080, not iMessage.
7. **If he mentions "mounting Google Drive"** — stop him. Use Hetzner file paths, not macOS mounts.

**Relay send template:**
```bash
curl -s -X POST "http://5.9.99.109:8080/message" \
  -H "X-API-Key: bgop-relay-k9x2mP8vQnJwT4rL" \
  -H "Content-Type: application/json" \
  -d @/home/user/workspace/message.json
```
Always write the message body to a file first — inline JSON with special characters breaks.

---

## HOW TO MANAGE CURSOR

Cursor runs on Ed's Mac with Desktop Commander. He is reliable but needs paste instructions.
The relay cannot reach Cursor directly — send to `both` or ask Ed to paste.

**Cursor's strengths:**
- SSH to Hetzner: `ssh -i /Users/Broyhill/.ssh/id_ed25519_hetzner root@5.9.99.109`
- File operations on Ed's Mac
- Loading CSV files via psql from Hetzner
- Running SQL against Supabase via psql (not the API)

**When loading files via psql always:**
```bash
export PGPASSWORD='Anamaria@2026@'
export PGSSLMODE=require
psql "postgresql://postgres@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres" -v ON_ERROR_STOP=1 <<'SQL'
SET statement_timeout = 0;
\copy table_name FROM '/path/to/file.csv' WITH (FORMAT csv, HEADER true, DELIMITER ',');
SQL
```

**Never use `Anamaria@2026@@` (double @) in the connection string** — URL-encode as
`Anamaria%402026%40` or use PGPASSWORD env var to avoid parsing issues.

---

## INFRASTRUCTURE

| Resource | Value |
|----------|-------|
| Hetzner Server 1 | 5.9.99.109 (primary — relay, GOD files) |
| Hetzner Server 2 | 144.76.219.24 (new — needs DataTrust IP whitelist) |
| SSH key | /Users/Broyhill/.ssh/id_ed25519_hetzner |
| Relay API key | bgop-relay-k9x2mP8vQnJwT4rL |
| GitHub repo | broyhill/BroyhillGOP |
| GitHub PAT | [PAT-stored-in-env] |
| DataTrust contact | Danny Gustafson dgustafson@gop.com 517-281-8018 |
| RNC address | 310 First Street SE, Washington DC 20003 |

---

## ACTIVE TO-DO LIST (April 8, 2026)

### IMMEDIATE — Awaiting Authorization
**1. Column migration** — `sessions/CONTACTS_COLUMN_MIGRATION.sql` committed by Claude.
   Adds 14 new columns to public.contacts, backfills from `custom_fields.datatrust_2026` JSON.
   Present to Ed, get "I authorize this action", then run.

### HIGH PRIORITY — Data Linkage (Primary Outstanding Work)
**2. Populate donor_id FK on fec_schedule_a_raw (856K rows) and nc_boe_donations_raw (277K rows).**
   Every donation record needs to link to its canonical donor in the donors table (1.2M rows, 457 golden records).
   Matching logic: normalize(last_name) + normalize(first_name) + zip5.
   Special case: Ed Broyhill golden record ID 150787 — 14 FEC name variants must all link to this record.
   Options: (A) Python REST API batch approach — stream donations, match to in-memory lookup, PATCH via REST.
   (B) Supabase SQL function approach (PREFERRED) — PL/pgSQL in-database match (much faster, needs SQL editor access).
   (C) Hybrid — export donors to CSV, match locally in Python, upload donorid assignments via PATCH.

**3. Entity Resolution Pass 3** — name+zip fuzzy matching on 1.2M unprocessed donors.
   Blocked by: donor linkage should happen first so we know which donors are already matched.

**4. Spouse/household tagging on nc_boe_donations_raw.**
   Parse donor_name (comma-separated last, first format), then:
   - Spouse match: same last_name + same address + different first_name.
   - Household cluster: md5(lower(trim(address)) || lower(trim(city)) || left(zip,5)).

**5. Reconcile staging_fec_contributions (272K rows) with fec_schedule_a_raw (856K rows).**
   Determine if staging records are duplicates or unique. If unique, merge them. If duplicates, can drop staging.

### THIS WEEK
**6. Danny Gustafson reply** — email sent April 2. Waiting on:
   - IP whitelist for 144.76.219.24 (blocks Server 2 API access)
   - RNCID in API responses (critical for live matching)
   - email_dt field (best dedup key — not in the 251-column file)
   - Additional coalition IDs beyond the current 7

**7. Remaining 85,566 unmatched contacts** — need voter_id match.
   Options: fuzzy name match (gin_trgm index on nc_datatrust), mailing zip vs reg zip,
   or wait for email_dt from Danny which solves most of these cleanly.

**8. WinRed → contacts backfill via RNCID** — once DataTrust new RNCIDs are reconciled,
   WinRed donors can be matched via DataTrust statevoterid bridge for higher confidence.

**9. Ecosystems deployment** — E01, E03, E15. Ed to confirm scope.

**10. AAA-86 Donor Scoring** — 3 behavioral letters (Persistence/Breadth/Responsiveness),
    A-F dash composite 0-100. Five dimensions: Persistence 0-20, Breadth 0-20,
    Responsiveness 0-20, Trajectory 0-20, Capacity 0-20. Maturity gate: 12 months, 4 gifts.
    DDL drafted for core.donor_behavioral_profile. NOT yet implemented — "continue to think about it" (Ed).

### QUEUED FOR CLAUDE
- **CONTACTS_COLUMN_MIGRATION.sql** — run after Ed authorization
- **Voter match for remaining 85,566** — design fuzzy match strategy using gin_trgm
- **Phase 1-7 architecture tables** — 20+ new tables designed March 31, not built yet.
  Full spec: `sessions/2026-03-31_MASTER_ARCHITECTURE_SESSION.md`
- **BroyhillGOPSchemaMigrationv1.sql** — schema changes from early sessions. NEVER DEPLOYED.

### BLOCKED (needs external action)
- **Hetzner Server Recovery** — rescue mode activated, pending hardware reboot.
  Container CANNOT reach Hetzner (connection timeout). Ed must trigger reset from Robot panel
  at robot.hetzner.com (login: edbroyhill.net / Melanie2026).
- **DataTrust 251-column file** — Azure link was expiring March 9, 2026. Blocked by Hetzner access.
  Verify with Ed if a new link was obtained. Download goes to Hetzner server.
- **Original Laravel database** — 243K donors, 555K donations from old platform. Migration status unknown.

### DO NOT DO WITHOUT ED
- Any TRUNCATE or DELETE on production tables
- Any new file load without verifying row count + header first
- Any merge execution on person_spine
- Contacting Danny Gustafson again (Ed sends his own emails)

---

## KEY FINANCIAL FIGURES
- Republican spine total: **$495,429,453**
- Archived Democratic + Unknown: $220,708,080
- **Ed Broyhill (golden record ID 150787):**
  - FEC (all time): 102 txn / $319,841 | NCBOE (all time): 151 txn / $320,622 | Combined: **$640,463**
  - 10-year total (2015-2024): ~$610-640K (vs Ed's claimed $625K — numbers track)
  - Known FEC name variants: BROYHILL ED, EDGAR, JAMES EDGAR, JAMES ED, JAMES E, J EDGAR, J. EDGAR, J E, J. E
  - JAMES T / JAMES T. / JAMES THOMAS BROYHILL = Senator James Thomas Broyhill **Sr. (Ed's father, deceased 2023)** — NOT Ed's uncle (corrected 2026-04-25 by Ed verbatim). Treatment: separate `legal_donor` identity in `core.di_person_canonical` as `JAMES_SR_BROYHILL`. `credited_to` rolls up to `ED_BROYHILL_FAMILY_OFFICE` per `SUPREME-MASTERPLAN/FAMILY-AND-DONOR-ROSTER.md` (same household model as Ed's wife Melanie Pennell and Ed's mother Louise). Address-based guard required: `JAMES T / JAMES THOMAS BROYHILL` rows from `5033 Gorham Dr` are Ed's son James II (out-of-scope, separate person_key `JAMES_II_BROYHILL`).
- Melanie Pennell Broyhill (wife): ~$45,755 total (FEC + NCBOE)
- AI team cost: ~$77.80/day / ~$2,334/mo (64 ecosystems, Claude model assignments per agent registry)

---

## ECOSYSTEM & AGENT REGISTRY (as of March 3, 2026)

- 64 ecosystems in agent registry (58 active; 8 sub-ecosystems absorbed into parents:
  E01b, E01c, E11b, E16b, E19b, E50, E56, E57)
- Full catalog: `BROYHILLGOP_ECOSYSTEM_CATALOG.docx` (668 paragraphs, 393 brands)
- Integration map: `BROYHILLGOP_ECOSYSTEM_INTEGRATION_MAP.docx` (940 paragraphs, 30 trigger chains, 4 new DDL tables)
- Agent registry: `BroyhillGOP_Ecosystem_Agent_Registry.xlsx` in repo root

### Faction Intensity (populated Feb 23)
- 2,303 candidates scored across 29 office types
- Intensity: 718 hardcore (31%), 1,446 strong (63%), 139 moderate (6%)
- Primary factions: FISC 28%, TRAD 16%, LAWS 14%, BUSI 12%, EVAN 12%, CHNA 7%, RUAL 6%, MAGA 6%

---

## FEC FILE — MATCHING STRATEGY (Read Before Touching fec_donations)

### What We Have
2,591,933 FEC Schedule A transactions — NC individual donors only, all cycles 2015-2026.
These are API exports filtered by contributor_state = NC. They are NOT bulk downloads.
Do not re-download or replace them.

### The Core Problem
The FEC donation address is where the donor WROTE ON THE CHECK — not where they are
registered to vote. Donors move. They give from vacation homes. They use work addresses.
This is why zip-code matching against nc_datatrust fails for many FEC donors.

### The Correct Matching Strategy (in order)

**Pass 1 — RNCID direct (fastest, most accurate)**
JOIN contacts → nc_datatrust ON norm_last + norm_first + LEFT(zip,5).
Use nc_datatrust norm columns and mailzip5 (not reg zip). Expected yield: 5,000-15,000.

**Pass 2 — Mailing zip vs reg zip (catches movers)**
JOIN on norm_last + norm_first + nc_datatrust.mailzip5 = contacts.zip5.
Expected yield: additional 3,000-8,000.

**Pass 3 — Address number match**
Extract house number from contributor_street_1 via REGEXP.
JOIN on norm_last + norm_first + addr_number. Expected yield: additional 1,000-3,000.

**Pass 4 — Email match (needs Danny's reply)**
Once email_dt is in nc_voters_fresh, JOIN contacts.email = nc_voters_fresh.email_dt.
Expected yield: 10,000-20,000 once email_dt is available.

**Pass 5 — DO NOT USE FUZZY MATCHING**
With Passes 1-4 plus email, fuzzy adds only ~500-800 marginal results with HIGH false positive rates.
Remaining ~50K truly unmatched contacts are genuinely out-of-state, deceased, or left NC.
RULE: Flag them as historical_unmatched and move on. Do not corrupt good data chasing bad matches.

### Key Indexes Already Built
- nc_datatrust: idx_nc_datatrust_norm_match (norm_last, norm_first, norm_zip5)
- nc_datatrust: idx_nc_datatrust_mailzip5 (norm_last, norm_first, mailzip5)
- nc_voters_fresh: idx_nvf_rncid, idx_nvf_statevoterid, idx_nvf_name_zip
- Always SET statement_timeout = 0 before any join against 7M+ row tables

---

## KEY PROVEN CODE PATTERNS (reuse these — don't reinvent)

### Supabase REST Batch Upload
```python
import requests
URL = "https://isbgjpnbocdkeslofota.supabase.co/rest/v1"
KEY = "eyJhbGci..."  # service role key
headers = {"apikey": KEY, "Authorization": f"Bearer {KEY}",
           "Content-Type": "application/json", "Prefer": "return=minimal"}
# CRITICAL: Every record in batch MUST have identical key set. Use None for missing values.
batch = [{"col1": val1, "col2": val2, ...} for row in chunk]
resp = requests.post(f"{URL}/fec_schedule_a_raw", headers=headers, json=batch)
# Achieves ~2000 recs/sec with batch size 1000
```

### Supabase REST Batch PATCH (for donor_id linking)
```python
for donor_id, record_ids in matches.items():
    resp = requests.patch(
        f"{URL}/fec_schedule_a_raw?id=in.({','.join(map(str, record_ids))})",
        headers=headers, json={"donor_id": donor_id}
    )
```

### Donor Name Normalization
```python
import re
def normalize(s):
    if not s: return ""
    return re.sub(r'[^a-z]', '', s.lower().strip())
def zip5(z):
    if not z: return ""
    return str(z).strip()[:5]
```

---

## GOD FILE V7 — Full Mac File Index

**URL:** http://5.9.99.109:8080/docs/v7
**What it is:** A searchable HTML index of 8,549+ files on Ed's Mac, deployed to Hetzner.
**Deployed:** April 3, 2026 — fully synced to GitHub and Hetzner

**Use this before asking Ed where a file is.** Search by filename, topic, or keyword.

**Search via relay:**
```bash
curl -s "http://5.9.99.109:8080/docs/search?q=KEYWORD&limit=20"
```

---

## SESSION TRANSCRIPT LOCATION
All session work logs: `https://github.com/broyhill/BroyhillGOP/tree/main/sessions/`
Key recent sessions:
- `sessions/2026-04-03_CURSOR_SESSION_AUDIT.md` — tonight's full state
- `sessions/2026-04-02_COMPLETE_DEDUP_V3.2.sql` — V3.2 dedup pipeline
- `sessions/MERGE_EXECUTOR_V1.sql` — executed, 4 merges done
- `sessions/CONTACTS_COLUMN_MIGRATION.sql` — pending authorization
- `sessions/DEDUP_REVIEW_APRIL2.md` — Perplexity's full merge candidate review
- `sessions/2026-03-31_MASTER_ARCHITECTURE_SESSION.md` — Phase 1-7 design
- GOD FILE transcripts: `2026-02-12-session-transcript-fec-load-donor-linkage.txt` (Session 7)
  and `2026-02-10-session-transcript-donor-files-hetzner.txt` (Session 6)

---

## FINAL NOTE

Ed spent 2+ hours onboarding this session because early mistakes required recovery.
The database was nearly corrupted by:
- A rogue bulk file from an unknown source (nc_donor_summary)
- Wrong BOE file loaded by Claude without verification
- Agents acting without reading session history first

**The STOP rule exists for a reason. Read everything first. Ask Ed before acting.
The database took months to build. One unauthorized TRUNCATE ends the project.**
