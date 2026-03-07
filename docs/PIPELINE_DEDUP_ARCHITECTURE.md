# Pipeline dedup architecture

## Decision: stored functions per Master Plan

**We follow the Master Plan.** Dedup key computation and (eventually) identity clustering are implemented as **Postgres stored functions/procedures**. Python `dedup.py` is or will become a **thin caller** of those procedures, not the logic owner. This scales to 7.6M+ voter identity resolution and keeps logic unit-testable in SQL.

## Implemented

- **`pipeline.dedup_key_fec_individual(...)`** (pipeline_ddl.sql §10.2b): Deterministic key for FEC Schedule A transaction-level dedup. Parameters: contributor_last_name, contributor_first_name, contributor_zip, committee_id, contribution_receipt_amount, contribution_receipt_date, report_id, line_number. Returns MD5 of concatenated values. Staging tables should have a `dedup_key` column set by this function after load.
- **`pipeline.dedup_key_ncboe(...)`** (existing): Same pattern for NC BOE.

## Current state of dedup.py

- **Identity clustering** (donor-level: last_name + zip + dmetaphone first_name → identity_clusters) is still implemented in **Python** and writes to `pipeline.identity_clusters`. This is acceptable as a temporary structure until the dedup architecture is fully migrated.
- **Next step:** Move matching/clustering into a stored procedure (e.g. `pipeline.run_dedup_fec_identity(...)`) that reads staging, applies rules, and inserts into identity_clusters. Then `dedup.py` will only call that procedure and pass through results.
