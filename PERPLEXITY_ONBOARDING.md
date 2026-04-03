# PERPLEXITY ONBOARDING — BroyhillGOP Platform
## Written by Perplexity, April 3, 2026 — READ THIS BEFORE DOING ANYTHING

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
WHERE relname IN ('contacts','nc_voters_fresh','nc_datatrust','nc_boe_donations_raw')
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

## DATABASE — TRUE CURRENT STATE (April 3, 2026 2:00 AM)

### Supabase Project
- **ID:** isbgjpnbocdkeslofota | **Region:** us-east-1 | **Postgres:** 17.6
- **Connection:** `postgresql://postgres:Anamaria@2026@@db.isbgjpnbocdkeslofota.supabase.co:5432/postgres`
- **Always set:** `SET statement_timeout = 0;` before heavy queries

### Key Table Row Counts (verified)

| Table | Rows | Notes |
|-------|------|-------|
| public.contacts | **227,978** | Master donor file |
| public.nc_datatrust | 7,661,978 | SACRED — do not touch |
| public.nc_boe_donations_raw | 338,223 | Individual only, no PACs |
| public.fec_donations | 2,591,933 | NC individual donors 2015-2026 |
| public.winred_donors | ~194,278 | NCGOP party donations |
| public.nc_donor_summary | 195,317 | PRESERVE — Letha Davis file |
| staging.nc_voters_fresh | 7,708,542 | DataTrust March 2026 full file |
| core.person_spine | 128,043 active | Republican donor spine |
| core.contribution_map | 4,137,549 | party_flag stamped |
| core.candidate_committee_map | 3,733 | 99.97% FEC coverage |

### Contacts Coverage

| Field | Count | % |
|-------|-------|---|
| Has voter_id (RNCID) | 142,412 | 62% |
| Has phone | 142,933 | 63% |
| Has mobile | 123,120 | 54% |
| Has email | 34,361 | 15% |
| Has republican_score | 137,328 | 60% |
| Has coalition data | 132,036 | 58% |
| Has congressional_district | ~140K | 61% |
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

## ACTIVE TO-DO LIST (April 3, 2026)

### IMMEDIATE — Awaiting Authorization
**1. Column migration** — `sessions/CONTACTS_COLUMN_MIGRATION.sql` committed by Claude.
   Review it. It adds 14 new columns and backfills from `custom_fields.datatrust_2026` JSON.
   Present to Ed, get "I authorize this action", then run.

### THIS WEEK
**2. Danny Gustafson reply** — email sent April 2. Waiting on:
   - IP whitelist for 144.76.219.24 (blocks Server 2 API access)
   - RNCID in API responses (critical for live matching)
   - email_dt field (best dedup key — not in the 251-column file)
   - Additional coalition IDs beyond the current 7

**3. Remaining 85,566 unmatched contacts** — need voter_id match.
   Options: fuzzy name match (gin_trgm index on nc_datatrust), mailing zip vs reg zip,
   or wait for email_dt from Danny which solves most of these cleanly.

**4. WinRed → contacts backfill via RNCID** — once DataTrust new RNCIDs are reconciled,
   WinRed donors can be matched via DataTrust statevoterid bridge for higher confidence.

**5. Ecosystems deployment** — E01, E03, E15. Ed to confirm scope.

### QUEUED FOR CLAUDE
- **CONTACTS_COLUMN_MIGRATION.sql** — run after Ed authorization
- **Voter match for remaining 85,566** — design fuzzy match strategy using gin_trgm
- **Phase 1-7 architecture tables** — 20+ new tables designed March 31, not built yet.
  Full spec: `sessions/2026-03-31_MASTER_ARCHITECTURE_SESSION.md`

### DO NOT DO WITHOUT ED
- Any TRUNCATE or DELETE on production tables
- Any new file load without verifying row count + header first
- Any merge execution on person_spine
- Contacting Danny Gustafson again (Ed sends his own emails)

---

## KEY FINANCIAL FIGURES
- Republican spine total: **$495,429,453**
- Archived Democratic + Unknown: $220,708,080
- Ed Broyhill (person_id 26451) total_contributed: $352,415.86

---

## SESSION TRANSCRIPT LOCATION
All session work logs: `https://github.com/broyhill/BroyhillGOP/tree/main/sessions/`
Most important recent sessions:
- `sessions/2026-04-03_SESSION-STATE.md` — tonight's full state
- `sessions/2026-04-02_COMPLETE_DEDUP_V3.2.sql` — V3.2 dedup pipeline
- `sessions/MERGE_EXECUTOR_V1.sql` — executed, 4 merges done
- `sessions/CONTACTS_COLUMN_MIGRATION.sql` — pending authorization
- `sessions/DEDUP_REVIEW_APRIL2.md` — Perplexity's full merge candidate review
- `sessions/2026-03-31_MASTER_ARCHITECTURE_SESSION.md` — Phase 1-7 design

---

## FINAL NOTE

Ed spent 2+ hours onboarding this session because early mistakes required recovery.
The database was nearly corrupted by:
- A rogue bulk file from an unknown source (nc_donor_summary)
- Wrong BOE file loaded by Claude without verification
- Agents acting without reading session history first

**The STOP rule exists for a reason. Read everything first. Ask Ed before acting.
The database took months to build. One unauthorized TRUNCATE ends the project.**
