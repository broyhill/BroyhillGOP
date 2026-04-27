# E61 — Source Ingestion & Identity Resolution Engine

**Status:** SPEC + skeleton code held in repo. **DDL execution BLOCKED** until donor identity pipeline (Stages 0-5) completes.
**Blueprint:** `ECOSYSTEM_REPORTS/E61_SOURCE_INGESTION_IDENTITY_RESOLUTION_BLUEPRINT.md` (central folder)
**Owner:** Ed Broyhill | Architect: Perplexity | Spec author: Claude (2026-04-27)

## What this folder contains

```
e61_source_ingestion_identity_resolution/
├── README.md                       this file
├── sql/
│   └── 001_e61_complete.sql        Layer 1+2+3+5 (DDL, indexes, RLS, triggers) — HELD, not executed
├── python/
│   └── e61/
│       ├── __init__.py
│       ├── normalize.py            Layer 5 — the canonical CSV pre-ingestion normalizer
│       ├── ingest.py               12-step orchestrator stub
│       ├── cluster_assign.py       cluster_id_v2 logic stub
│       └── datatrust_match.py      T1-T6 ladder stub
└── data/lookups/
    ├── nickname_pairs.csv          legal-first ↔ common-first seed
    └── nonperson_tokens.csv        corporate/PAC token blacklist
```

## How E61 plugs in (recap)

```
E24 Candidate Portal ──┐
E25 Donor Portal ──────┼──→ POST /e61/upload ──→ E61 ──→ E15 / E01 / E03 (canonical)
Direct batch ──────────┘                          │
                                                  ├──→ E20 Brain (telemetry)
                                                  ├──→ E27 Realtime (status)
                                                  ├──→ E51 Prime Command (KPIs)
                                                  └──→ E21 ML (training feed + plug-in callbacks)
```

## Why DDL execution is held

Per `broyhillgop:ecosystem-management` skill: *"Do NOT create ecosystem database tables until the donor identity pipeline is complete (Stages 0-5 of the remediation plan)."* The skeleton lives in this repo so all agents (Claude, Cursor, Perplexity) can review, refine, and prep — but no one runs the SQL until Ed authorizes Phase 1.

## Activation gate

Phase 1 (Layer 1 DDL on Hetzner) requires ALL of:
1. Donor identity pipeline complete (Path B' + C₂ on `staging.ncboe_party_committee_donations` landed; canaries intact)
2. `user_roles` table exists (Layer 3 RLS dependency)
3. `organization_id` reconciled on `candidate_profiles` (Layer 3 RLS dependency)
4. `candidate_id` UUID-vs-VARCHAR type mismatch resolved
5. Ed types `AUTHORIZE`

Until then, this folder is a held artifact — readable, reviewable, indexed by morning_scrape, but inert.

## Next steps after activation

- Phase 2: implement Python engine (real `normalize.py`, `ingest.py`, `cluster_assign.py`, `datatrust_match.py`) and re-ingest `republican-party-committees-2015-2026.csv` as the validation case. Match rate must hit ≥75% before Phase 3.
- Phase 3: Layer 4 API (Supabase Edge Functions) + portal hand-offs (E24, E25)
- Phase 4: Layer 6 Brain hooks + Layer 6.5 ML plug-ins (E20, E21)
- Phase 5: Layer 7 Inspinia admin pages
- Phase 6: cutover, retire legacy ad-hoc Stage 1-2 scripts
