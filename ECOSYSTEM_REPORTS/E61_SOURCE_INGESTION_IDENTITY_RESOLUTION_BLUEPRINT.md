# E61 — Source Ingestion & Identity Resolution Engine (SIIRE)

**Version:** 1.0 (2026-04-27, Claude blueprint draft for Perplexity review)
**Status:** SPEC ONLY — implementation BLOCKED until donor identity pipeline (Stages 0-5) completes (skill rule)
**Owner:** Ed Broyhill | Architect: Perplexity | Spec author: Claude
**Universe:** DATA / CONTENT-AI hybrid

---

## 1. Mission

Single ingress point for every messy CSV, spreadsheet, or upload that wants to become a canonical donor / contact / candidate record. Every external file flows through this ecosystem before touching `core.*` schemas. Replaces today's ad-hoc Stage 1-2 scripts with an architected service.

**Three classes of input it accepts:**
1. **Bulk batch** — NCBOE, FEC, Acxiom, DataTrust refreshes (no UI, file-drop or API push)
2. **Candidate uploads** — via E24 Candidate Portal (their personal contact lists, donor lists they bring)
3. **Donor uploads** — via E25 Donor Portal (donors uploading lists of friends to ask)

**Single output contract:** every row leaves with `(canonical_record_id, cluster_id_v2, rnc_regid_v2, state_voter_id_v2, match_tier, match_confidence, source_lineage)` — or goes to a quarantine queue with a reason code.

---

## 2. Plug-in topology — integration with existing ecosystems

```
                                 INPUTS (3 paths)
   ┌─────────────────────────────────────────────────────────────────┐
   │                                                                 │
   │  E24 Candidate Portal              E25 Donor Portal             │
   │  (browser file upload)             (browser file upload)        │
   │           │                                  │                  │
   │           ▼                                  ▼                  │
   │  POST /e61/upload                   POST /e61/upload            │
   │  (with source=candidate)            (with source=donor)         │
   │                                                                 │
   │              Direct batch (NCBOE / FEC / Acxiom / DataTrust)    │
   │                              │                                  │
   │                              ▼                                  │
   │                   POST /e61/upload (source=batch)               │
   └────────────────────────────┬────────────────────────────────────┘
                                │
                                ▼
   ┌─────────────────────────────────────────────────────────────────┐
   │   E61  SOURCE INGESTION & IDENTITY RESOLUTION ENGINE            │
   │   Layer 1-7 (this blueprint)                                    │
   └────────┬──────────────────────────────────────────────┬─────────┘
            │                                              │
   OUTPUTS  ▼                                              ▼  TELEMETRY
   ┌─────────────────────────────────────┐    ┌──────────────────────┐
   │ E15 Contact Directory               │    │ E20 Intelligence     │
   │   ← canonical contact records       │    │     Brain            │
   │ E01 Donor Intelligence              │    │   ← match-rate, dark │
   │   ← matched donor identities        │    │     anomalies, drift │
   │ E03 Candidate Management            │    │ E27 Realtime         │
   │   ← candidate identities            │    │     Dashboard        │
   │ E02 Donation Processing             │    │   ← run status, ETA  │
   │   ← attribution-ready transactions  │    │ E51 Prime Command    │
   │ E52 Contact Intelligence            │    │   ← KPIs, alerts     │
   │   ← enrichment-ready records        │    └──────────────────────┘
   └─────────────────────────────────────┘

                    ML CALLBACKS (bidirectional)
   ┌─────────────────────────────────────────────────────────────────┐
   │  E21 Machine Learning  ──[fuzzy-match-threshold tuning]──> E61  │
   │  E21 Machine Learning  ──[nickname classifier]───────────> E61  │
   │  E21 Machine Learning  ──[address-parse model]───────────> E61  │
   │  E61  ──[labeled training data: matched + dark]─────> E21      │
   └─────────────────────────────────────────────────────────────────┘

                    INFRASTRUCTURE
   ┌─────────────────────────────────────────────────────────────────┐
   │  E40 Automation Control  ──[cron / webhook / event]──> E61     │
   │  E55 API Gateway         ──[routes /e61/* endpoints]──> E61    │
   │  E54 Calendar            ──[scheduled batch loads]──> E61      │
   └─────────────────────────────────────────────────────────────────┘
```

**Plug-in specs:**

| Direction | Channel | Contract |
|---|---|---|
| E24 → E61 | HTTP POST `/e61/upload` with `source=candidate, candidate_id, file` | Returns `ingestion_run_id` |
| E25 → E61 | HTTP POST `/e61/upload` with `source=donor, donor_id, file` | Returns `ingestion_run_id` |
| Batch → E61 | File drop in `staging.dropbox.<source>/` watched by E40, OR HTTP POST | Returns `ingestion_run_id` |
| E61 → E15 | INSERT/UPSERT to `public.contacts` with `cluster_id_v2`, lineage | Idempotent on `cluster_id_v2 + source_row_id` |
| E61 → E01 | INSERT to `core.donor_master_proposed` (held until Ed AUTHORIZE for staging→core) | Idempotent on `donor_master_id` |
| E61 → E03 | INSERT to `core.candidate_contact_proposed` | Idempotent |
| E61 → E20 | Pub/Sub event `e61.run.completed` with metrics payload | Brain logs to E20 audit |
| E61 → E21 | Bulk export of `(matched, dark, quarantined)` labeled rows monthly | E21 retrains models |
| E21 → E61 | REST `/e21/nickname-classifier/predict` and `/e21/fuzzy-threshold/get` | E61 calls per row or per batch |

---

## 3. Directory structure

```
/Users/Broyhill/Desktop/BroyhillGOP-CURSOR/
└── ecosystems/
    └── e61_source_ingestion_identity_resolution/
        ├── README.md                                  ← architecture overview, quickstart
        ├── BLUEPRINT.md                               ← this file (canonical spec)
        ├── CHANGELOG.md
        │
        ├── sql/                                       ← Layer 1, 2, 3, 5
        │   ├── 001_e61_ddl.sql
        │   ├── 002_e61_indexes.sql
        │   ├── 003_e61_rls.sql
        │   ├── 004_e61_triggers.sql
        │   ├── 005_e61_lookup_tables.sql              ← zip→county, NCSBE prefix, nickname pairs
        │   └── 099_e61_rollback.sql
        │
        ├── python/                                    ← runtime engine
        │   ├── e61/
        │   │   ├── __init__.py
        │   │   ├── ingest.py                          ← orchestrator
        │   │   ├── normalize.py                       ← case/whitespace/zip/nickname
        │   │   ├── address_parse.py                   ← component parsing
        │   │   ├── cluster_assign.py                  ← cluster_id_v2 logic
        │   │   ├── datatrust_match.py                 ← T1-T6 tier ladder
        │   │   ├── dark_recovery.py                   ← Path B' + C₂ on residual
        │   │   ├── lineage.py                         ← provenance stamper
        │   │   ├── quarantine.py                      ← bad-row routing
        │   │   ├── canary.py                          ← Ed/Pope/Melanie verification
        │   │   └── publish.py                         ← downstream notify (E15/E01/E03/E20)
        │   ├── tests/
        │   │   ├── test_normalize.py
        │   │   ├── test_cluster.py
        │   │   ├── test_match.py
        │   │   ├── test_canary.py
        │   │   └── fixtures/
        │   │       ├── broyhill_variants.csv          ← the 7-name test case
        │   │       ├── renee_hill_doublespace.csv     ← the address normalization test
        │   │       └── tate_corporate_lookalike.csv   ← the false-positive test
        │   └── pyproject.toml
        │
        ├── api/                                       ← Layer 4 (Supabase Edge Functions)
        │   ├── upload.ts                              ← POST /e61/upload
        │   ├── status.ts                              ← GET /e61/runs/:id
        │   ├── quarantine_list.ts                     ← GET /e61/quarantine
        │   ├── quarantine_resolve.ts                  ← POST /e61/quarantine/:id/resolve
        │   ├── rerun.ts                               ← POST /e61/runs/:id/rerun
        │   ├── metrics.ts                             ← GET /e61/metrics
        │   └── deno.json
        │
        ├── ml/                                        ← E21 plug-ins
        │   ├── nickname_classifier/                   ← legal ↔ common-name model
        │   │   ├── train.py
        │   │   ├── infer.py
        │   │   └── seed_pairs.csv                     ← hand-curated nickname pairs
        │   ├── fuzzy_threshold/                       ← per-zip Levenshtein cutoff
        │   │   └── tune.py
        │   └── anomaly_detector/                      ← bad-row pattern detection
        │       └── score.py
        │
        ├── brain/                                     ← Layer 6 (E20 hooks)
        │   ├── rules/
        │   │   ├── canary_breach.yaml
        │   │   ├── dark_donor_drift.yaml
        │   │   ├── source_file_signature.yaml         ← detect double-loads
        │   │   └── corporate_in_name_field.yaml       ← the 105-row pattern
        │   └── dashboards/
        │       └── e61_health.json
        │
        ├── admin/                                     ← Layer 7 (Inspinia control panel)
        │   ├── inspinia/
        │   │   ├── dashboard.html                     ← run history, KPIs, canary status
        │   │   ├── upload.html                        ← drag-drop file UI
        │   │   ├── runs.html                          ← per-run drill-down
        │   │   ├── quarantine.html                    ← review + manual fix
        │   │   ├── rules.html                         ← edit normalization rules
        │   │   └── lineage.html                       ← trace any contact back to source
        │   └── README.md
        │
        ├── docs/
        │   ├── 7_LAYERS.md                            ← this blueprint expanded per layer
        │   ├── INTEGRATION_E15.md                     ← contract with Contact Directory
        │   ├── INTEGRATION_E20.md                     ← Brain telemetry contract
        │   ├── INTEGRATION_E21.md                     ← ML callback contract
        │   ├── INTEGRATION_E24_E25.md                 ← portal upload contract
        │   ├── NORMALIZATION_RULES.md                 ← the canonical rules table
        │   └── RUNBOOK.md                             ← ops procedures
        │
        └── data/
            ├── lookups/
            │   ├── nc_zip_to_county.csv
            │   ├── ncsbe_county_prefix.csv           ← 2-letter SVI prefix → county
            │   ├── nickname_pairs.csv                ← Ed↔Edgar, Bob↔Robert, etc.
            │   └── nonperson_token_blacklist.csv    ← Pipe, Foundry, Inc, etc.
            └── seed/
                └── (sample test data for dev)
```

---

## Layer 1 — DDL

**Schema:** `e61` (new schema, separate from `core` and `staging`)

```sql
-- Source registration: who is allowed to push and what their format expectations are
CREATE TABLE e61.source_registry (
    source_id           TEXT PRIMARY KEY,                  -- e.g. 'ncboe_party_committee', 'candidate_upload', 'donor_upload'
    source_kind         TEXT NOT NULL,                     -- 'batch','portal_candidate','portal_donor','api_push'
    schema_version      INT  NOT NULL DEFAULT 1,
    expected_columns    JSONB NOT NULL,                    -- column-name -> required/optional + canonical-name mapping
    normalization_rules JSONB NOT NULL,                    -- per-column transforms (UPPER, BTRIM, regex)
    canonical_dest      TEXT NOT NULL,                     -- 'core.donor_master','core.candidate_contact','public.contacts'
    auto_match_enabled  BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Each ingestion event (one CSV/upload = one run)
CREATE TABLE e61.ingestion_run (
    run_id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id           TEXT NOT NULL REFERENCES e61.source_registry(source_id),
    submitter_user_id   UUID,                              -- candidate, donor, admin who uploaded
    submitter_role      TEXT,                              -- 'candidate','donor','admin','automation'
    file_name           TEXT NOT NULL,
    file_sha256         TEXT NOT NULL,                     -- detect double-uploads
    file_size_bytes     BIGINT,
    row_count_input     BIGINT,
    started_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
    completed_at        TIMESTAMPTZ,
    status              TEXT NOT NULL DEFAULT 'queued',    -- queued/normalizing/clustering/matching/publishing/done/failed/quarantined
    error_msg           TEXT,
    metrics             JSONB                              -- {match_rate, dark_clusters, canary_status, ...}
);

-- Every row from the input CSV, stamped with lineage
CREATE TABLE e61.ingested_row (
    ingested_row_id     UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    run_id              UUID NOT NULL REFERENCES e61.ingestion_run(run_id) ON DELETE CASCADE,
    source_row_index    BIGINT NOT NULL,                   -- row number in the original file
    raw_payload         JSONB NOT NULL,                    -- the raw row, preserved verbatim
    normalized_payload  JSONB,                             -- after Layer 5 normalization
    cluster_id_v2       BIGINT,                            -- assigned by cluster step
    rnc_regid_v2        TEXT,                              -- assigned by match step
    state_voter_id_v2   TEXT,
    match_tier          TEXT,                              -- T1..T6, or NULL if dark
    match_method        TEXT,                              -- 'last_first_zip', 'nickname_expand', etc.
    match_confidence    NUMERIC(4,3),                      -- 0.000-1.000
    canonical_dest_id   TEXT,                              -- the contact_id / donor_id / candidate_id we landed on
    quarantine_reason   TEXT,                              -- NULL if clean, else a code
    UNIQUE (run_id, source_row_index)
);

-- Quarantine queue for rows that fail normalization or violate doctrine
CREATE TABLE e61.quarantine (
    quarantine_id       UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ingested_row_id     UUID NOT NULL REFERENCES e61.ingested_row(ingested_row_id),
    reason_code         TEXT NOT NULL,                     -- 'corporate_name_in_name_field', 'broken_zip', 'unparsable_addr', etc.
    reason_detail       TEXT,
    suggested_fix       JSONB,                             -- what the system thinks the row should be
    resolution_status   TEXT NOT NULL DEFAULT 'open',      -- open/manual_fixed/dropped/auto_fixed
    resolved_by_user_id UUID,
    resolved_at         TIMESTAMPTZ
);

-- Lineage: the full chain from raw row → cluster → match → canonical record
CREATE TABLE e61.lineage_link (
    lineage_id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_table     TEXT NOT NULL,                     -- 'public.contacts','core.donor_master'
    canonical_id        TEXT NOT NULL,
    ingested_row_id     UUID NOT NULL REFERENCES e61.ingested_row(ingested_row_id),
    contribution_kind   TEXT,                              -- 'created','updated_field','merged_into','no_op'
    created_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Lookup tables (Layer-1 reference data)
CREATE TABLE e61.lookup_zip_county     (zip5 TEXT PRIMARY KEY, county_name TEXT NOT NULL);
CREATE TABLE e61.lookup_county_prefix  (sbe_prefix CHAR(2) PRIMARY KEY, county_name TEXT, state_county_code TEXT);
CREATE TABLE e61.lookup_nickname_pair  (legal_first TEXT, common_first TEXT, PRIMARY KEY (legal_first, common_first));
CREATE TABLE e61.lookup_nonperson_token(token TEXT PRIMARY KEY, kind TEXT);  -- LLC, INC, FOUNDATION, FOUNDRY, ...
```

**Type-mismatch warnings (per skill):**
- `candidate_id` is VARCHAR in `candidate_profiles` — when E61 publishes to E03, cast UUID↔VARCHAR explicitly. Reconcile before any FK constraint.
- `user_roles` table is missing — Layer 3 RLS will use a placeholder until it exists; flag for follow-up.
- `organization_id` missing on `candidate_profiles` — Layer 3 RLS will scope to candidate_id alone for now.

---

## Layer 2 — Indexes

```sql
-- ingestion_run: status dashboards, file-dedup detection
CREATE INDEX ix_e61_run_source_started ON e61.ingestion_run(source_id, started_at DESC);
CREATE INDEX ix_e61_run_status         ON e61.ingestion_run(status) WHERE status NOT IN ('done','failed');
CREATE UNIQUE INDEX ux_e61_run_sha     ON e61.ingestion_run(file_sha256, source_id);  -- prevents double-load

-- ingested_row: lookup, cluster joins, quarantine review
CREATE INDEX ix_e61_irow_run           ON e61.ingested_row(run_id);
CREATE INDEX ix_e61_irow_cluster       ON e61.ingested_row(cluster_id_v2) WHERE cluster_id_v2 IS NOT NULL;
CREATE INDEX ix_e61_irow_rnc           ON e61.ingested_row(rnc_regid_v2)  WHERE rnc_regid_v2  IS NOT NULL;
CREATE INDEX ix_e61_irow_quarantine    ON e61.ingested_row(quarantine_reason) WHERE quarantine_reason IS NOT NULL;

-- quarantine
CREATE INDEX ix_e61_q_status           ON e61.quarantine(resolution_status, reason_code) WHERE resolution_status='open';

-- lineage
CREATE INDEX ix_e61_lin_canonical      ON e61.lineage_link(canonical_table, canonical_id);
CREATE INDEX ix_e61_lin_irow           ON e61.lineage_link(ingested_row_id);

-- lookup tables (small but joined hot)
CREATE INDEX ix_e61_nick_common        ON e61.lookup_nickname_pair(common_first);
```

---

## Layer 3 — RLS

Six roles assumed (require `user_roles` table to exist — see warning above):

```sql
ALTER TABLE e61.ingestion_run     ENABLE ROW LEVEL SECURITY;
ALTER TABLE e61.ingested_row      ENABLE ROW LEVEL SECURITY;
ALTER TABLE e61.quarantine        ENABLE ROW LEVEL SECURITY;
ALTER TABLE e61.lineage_link      ENABLE ROW LEVEL SECURITY;

-- Admins see everything
CREATE POLICY e61_admin_all ON e61.ingestion_run  FOR ALL TO authenticated USING (auth.user_has_role('admin'));
CREATE POLICY e61_admin_all ON e61.ingested_row   FOR ALL TO authenticated USING (auth.user_has_role('admin'));
CREATE POLICY e61_admin_all ON e61.quarantine     FOR ALL TO authenticated USING (auth.user_has_role('admin'));
CREATE POLICY e61_admin_all ON e61.lineage_link   FOR ALL TO authenticated USING (auth.user_has_role('admin'));

-- Candidates see only their own uploads
CREATE POLICY e61_candidate_own_runs ON e61.ingestion_run FOR SELECT TO authenticated
  USING (auth.user_has_role('candidate') AND submitter_user_id = auth.uid());

-- Donors see only their own uploads
CREATE POLICY e61_donor_own_runs ON e61.ingestion_run FOR SELECT TO authenticated
  USING (auth.user_has_role('donor') AND submitter_user_id = auth.uid());

-- Staff (campaign ops) see all runs but cannot delete
CREATE POLICY e61_staff_read ON e61.ingestion_run FOR SELECT TO authenticated USING (auth.user_has_role('staff'));

-- Automation service account has INSERT/UPDATE on ingestion_run + ingested_row + quarantine
CREATE POLICY e61_svc_write ON e61.ingestion_run FOR INSERT TO service_role WITH CHECK (true);
-- ...similar for ingested_row, quarantine, lineage_link
```

---

## Layer 4 — API (Supabase Edge Functions)

```
POST   /e61/upload                    Accepts file + source metadata; returns run_id
GET    /e61/runs/:run_id              Status, metrics, ETA
GET    /e61/runs/:run_id/rows         Paged ingested_row results
GET    /e61/quarantine                Open quarantine items (filtered by RLS)
POST   /e61/quarantine/:id/resolve    Apply manual fix or drop
POST   /e61/runs/:run_id/rerun        Reprocess a run (after quarantine fixes or rule update)
GET    /e61/metrics                   Aggregate KPIs for E51 Prime Command + E27 Realtime
GET    /e61/lineage/:canonical_id     Trace canonical record back to all source rows
POST   /e61/sources                   Register a new source (admin only)
GET    /e61/sources                   List registered sources
```

All endpoints route through E55 API Gateway. Authentication via Supabase JWT.

---

## Layer 5 — Triggers + Engine code

Pure SQL triggers are minimal (DB stays light). The engine logic lives in Python (`python/e61/`) called by the Edge Function via Supabase RPC or queue.

**Two SQL triggers:**

```sql
-- 1) When ingestion_run.status flips to 'done', fire pub/sub to E20 Brain
CREATE FUNCTION e61.notify_brain_run_done() RETURNS trigger AS $$
BEGIN
  IF NEW.status = 'done' AND OLD.status <> 'done' THEN
    PERFORM pg_notify('e20_brain', json_build_object(
      'event','e61.run.completed',
      'run_id', NEW.run_id,
      'source_id', NEW.source_id,
      'metrics', NEW.metrics
    )::text);
  END IF;
  RETURN NEW;
END$$ LANGUAGE plpgsql;
CREATE TRIGGER trg_e61_run_done AFTER UPDATE ON e61.ingestion_run FOR EACH ROW EXECUTE FUNCTION e61.notify_brain_run_done();

-- 2) When a quarantine row is resolved, decrement the open count for E27 dashboard
CREATE TRIGGER trg_e61_q_resolved AFTER UPDATE ON e61.quarantine FOR EACH ROW EXECUTE FUNCTION e61.refresh_e27_metrics();
```

**Python engine flow** (per `python/e61/ingest.py`):

```
1. validate_source(source_id, file_sha256)              ← source_registry, dedup check
2. snapshot_to_archive(file)                            ← archive raw file
3. parse_csv_to_rows(file) -> ingested_row[]            ← row-by-row, raw_payload preserved
4. normalize_rows(rows, rules)                          ← upper, btrim, ws-collapse, zip-pad, nickname-extract
5. component_parse_addresses(rows)                      ← {number, predir, name, type, unit}
6. assign_cluster_id(rows)                              ← alphabetical-adjacency + last+first+zip5
7. match_datatrust(rows) -> match_tier T1..T6           ← ladder: literal -> initial -> nickname -> mailzip -> address-num -> county-anchor
8. dark_recovery(unmatched_rows)                        ← Path B' (smart fallbacks) + C₂ (adjacency-merge)
9. canary_verify(run)                                   ← Ed/Pope/Melanie unchanged
10. publish_to_canonical(rows)                          ← E15/E01/E03 with lineage_link rows
11. emit_metrics(run)                                   ← E20 + E27 + E51
12. mark_run_done(run_id)                               ← triggers Layer-5 notify
```

---

## Layer 6 — Brain Integration (E20)

E20 subscribes to `e61.run.completed` events and applies four rule families:

```yaml
# brain/rules/canary_breach.yaml
on_event: e61.run.completed
condition: metrics.canary_status != "all_intact"
action:
  - alert_severity: critical
  - notify: [ed, perplexity, claude, cursor]
  - block_publish: true   # halt the run from reaching E15/E01/E03

# brain/rules/dark_donor_drift.yaml
on_event: e61.run.completed
condition: metrics.dark_rate > 0.45 AND source_kind = 'batch'
action:
  - alert_severity: warning
  - log_to: e20.anomaly_log
  - hint: "Dark rate above baseline; check for new format variant"

# brain/rules/source_file_signature.yaml
on_event: e61.run.queued
condition: e61.ingestion_run already has same file_sha256 within 48h
action:
  - alert_severity: warning
  - block: true
  - reason: "Probable double-load; verify before re-running"

# brain/rules/corporate_in_name_field.yaml
on_event: e61.row.normalized
condition: name matches /\b(LLC|INC|CORP|FOUNDATION|TRUST|FOUNDRY|PIPE|PARTNERS|HOLDINGS|REALTY)\b/
action:
  - quarantine: corporate_name_in_name_field
  - suggested_fix: "Search for individual donor at this address; possibly NCBOE clerk error"
```

E20 also gets a **monthly retraining feed**:
- Matched rows (clean labels): name + address + RNC pair → positive examples for E21 nickname classifier
- Dark rows (after C₂): name + address + no-match → negative examples for fuzzy threshold tuning
- Quarantine resolutions (manual): the human fix becomes a labeled rule

---

## Layer 6.5 — Machine Learning Integration (E21)

Three model plug-ins, called by E61 at match time:

| Model | Lives in | E61 calls | E21 trains on |
|---|---|---|---|
| **Nickname Classifier** | `ml/nickname_classifier/` | `predict(common_first) -> [legal_first, ...]` | seed_pairs.csv + labeled matches from past runs |
| **Per-zip Fuzzy Threshold** | `ml/fuzzy_threshold/` | `get(zip5) -> levenshtein_max` | dense urban zips need tighter, rural can be looser |
| **Anomaly Detector** | `ml/anomaly_detector/` | `score(row) -> 0.0-1.0` | flags rows that look "weird" — quarantine candidates |

**Training cadence:** monthly. E61 dumps training data to `e21.training_feed` table; E21 picks up, retrains, publishes new model version. E61 reads model version from `e21.model_registry`.

---

## Layer 7 — Inspinia Admin (Control Panel)

Five HTML pages under `admin/inspinia/`, all mounted at `/admin/e61/*` via E51 Prime Command:

| Page | Purpose | Audience |
|---|---|---|
| **dashboard.html** | KPIs: today's runs, % matched, quarantine queue depth, canary status, drift alerts. Charts. | Ed, Perplexity, admin staff |
| **upload.html** | Drag-and-drop CSV uploader with source-template auto-detect. Shows pre-flight validation before submitting. | Anyone with upload role |
| **runs.html** | Run history with filter (source, date range, submitter, status). Per-row drill-down to the raw + normalized + match output. | Admin, staff |
| **quarantine.html** | Quarantine queue with reason-code filter. Manual fix UI + bulk-drop button. Shows suggested_fix beside the row. | Admin, staff |
| **rules.html** | Edit normalization rules per source. Versioned. Diff-and-preview before save. | Admin only |
| **lineage.html** | Search any canonical contact_id; see every source row that contributed to it, in date order. | Admin, audit |

---

## What this ecosystem replaces / unifies

| Today (ad-hoc) | After E61 (canonical) |
|---|---|
| Stage 1 NCBOE loader script | source_id `ncboe_party_committee` registered in `source_registry` |
| `cluster_id_v2` assignment in scattered SQL | `python/e61/cluster_assign.py` |
| Ad-hoc match passes `stage2_pass1`..`pass6` | `python/e61/datatrust_match.py` (T1-T6 ladder) |
| Manual normalization (each source different) | one `normalize.py` driven by `source_registry.normalization_rules` |
| No quarantine — bad rows silently dropped or polluted | `e61.quarantine` table with reason codes + manual review UI |
| No lineage — can't answer "where did this contact come from?" | `e61.lineage_link` traces canonical → source row |
| Excel-touched files sneak in | file_sha256 dedup + corporate-in-name detection at Layer 5 |
| Match rate measured by ad-hoc query | `metrics` JSONB on every run + E27 dashboard |

---

## Implementation phasing

Per skill warning, **DDL execution is BLOCKED until donor identity pipeline (current work) completes**. Phasing:

1. **Phase 0 (NOW):** Spec frozen (this document). Perplexity reviews. Ed approves.
2. **Phase 1 (after current donor identity work lands):** Layer 1 DDL on Hetzner. Lookup tables seeded. (~1 day)
3. **Phase 2:** Python engine (`python/e61/`) + tests. NCBOE party committee re-ingested through E61 as the validation case (today's file becomes the test fixture). (~1 week)
4. **Phase 3:** Layer 4 API (Edge Functions) + portal hand-offs (E24, E25). (~1 week)
5. **Phase 4:** Layer 6 Brain hooks + Layer 6.5 ML plug-ins. (~1 week)
6. **Phase 5:** Layer 7 Inspinia admin. (~3 days)
7. **Phase 6:** Cutover — all future ingestions route through E61, legacy scripts retired.

**Validation gate at end of Phase 2:** re-ingest `republican-party-committees-2015-2026.csv` through E61. Match rate must hit ≥75% (vs. current 39%) and all canaries must be intact, or Phase 3 doesn't start.

---

## Open questions for Ed / Perplexity

1. **Number lock.** Default `E61` (next clean slot after E60). Override if you've assigned E61 to something else.
2. **Schema name lock.** Default `e61`. Some plats prefer `ingestion` as the schema name. Either works.
3. **Inspinia mount path.** `/admin/e61/*` under E51 Prime Command — confirm or pick another mount point.
4. **ML training cadence.** Monthly proposed. Want weekly?
5. **Type mismatches** (candidate_id VARCHAR vs UUID, missing user_roles, missing organization_id) — should Phase 0 include reconciling these, or are they Phase 1 work?
6. **Dependency on donor identity pipeline.** This blueprint assumes Stages 0-5 are complete before Phase 1 begins. Is that timeline still ~2 weeks, or should we plan for E61 in parallel?

---

_Spec author: Claude (Anthropic), 2026-04-27. Format follows the BroyhillGOP 7-layer convention. Implementation BLOCKED until donor identity pipeline completes (skill rule). Next step: Perplexity review + Ed approve._
