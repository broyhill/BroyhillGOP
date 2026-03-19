# Claude Instructions: BroyhillGOP Database Rebuild (RFC-001)

**For:** Any Claude or Cursor AI session working on BroyhillGOP database, identity, or pipeline.  
**Source of truth:** RFC-001 ([Claude-Cursor-ecosystems.md](../Claude-Cursor-ecosystems.md) in repo root).  
**Last updated:** 2026-03-01

---

## 1. Rebuild, Not Clean

- **We are rebuilding the identity layer, not cleaning existing data.**
- Do **not** run destructive merge/dedupe on `public.golden_records` or any existing public tables.
- **Do not seed `core.person_spine` from `donor_golden_records`, `person_master`, or any golden/master table.** Build the spine **only** from multi-pass identity resolution on norm tables. Start with an empty spine; create spine rows only when a norm record matches an existing spine row or cannot match (new person). Any copy-from-golden approach violates RFC-001 and defeats the rebuild.
- Norm tables **must** include `voter_ncid` and `email` (and `employer` for Pass 5) before running identity resolution. If they do not, fix the norm ETL first — add the columns and backfill from voter links, donor contacts, FEC, etc. Do not report "6-pass resolution" when only Pass 3 (name+zip) can run.
- Populate the spine by:
  - Creating `raw`, `norm`, and `core` schemas and RFC-001 tables (empty).
  - Populating `norm.*` from raw sources (BOE, FEC), **including** voter_ncid, email, employer where available.
  - Running **multi-pass identity resolution** so that norm rows get `person_id` and `core.person_spine` / `core.identity_clusters` are populated.
  - Populating `core.contribution_map` and `core.candidate_committee_map` from norm + committee map.
- Leave all existing public tables (including `golden_records`) **unchanged** until the new spine is validated and Eddie approves archive/drop.

---

## 2. RFC-001 as Authority

- **Architecture and DDL:** Follow [Claude-Cursor-ecosystems.md](../Claude-Cursor-ecosystems.md) (RFC-001) for:
  - Schema roles: `raw` (immutable source), `norm` (normalized, `person_id` nullable until resolved), `core` (person_spine, contribution_map, candidate_committee_map, identity_clusters, etc.).
  - Exact table definitions: `core.person_spine`, `core.person_names`, `core.person_addresses`, `core.nick_group`, `core.vip_overrides`, `core.preferred_name_cache`, `core.salutation_parts`, `core.candidate_committee_map`, `core.contribution_map`, `core.identity_clusters`.
  - Multi-pass blocking order: (1) voter_ncid, (2) email, (3) norm_last+norm_first+zip5, (4) nickname+zip5, (5) first_initial+zip5+employer, (6) cross-zip with secondary signal.
  - Preferred name: source-weighted inference; VIP overrides win.
  - Validation queries in RFC-001 Section 4 must pass before considering the rebuild complete.
- **Migration sequence:** Execute phases in RFC-001 Section 5 (0–17). Heavy phases (norm ETL, resolution, contribution_map) run on **Hetzner**; schema/seed/validation on Supabase SQL where appropriate.

---

## 3. Ecosystem and Catalog Constraints

- **No new ecosystem tables** until the golden-record identity layer (core.person_spine) is in place and validated (per BROYHILLGOP_ECOSYSTEM_CATALOG.docx).
- All 58 ecosystems depend on a single person spine and shared event bus; E20 (Intelligence Brain) and cost/benefit/toggle design assume `core` as the FK source for person_id.
- When designing pipelines or DDL, preserve compatibility with:
  - [BROYHILLGOP_ECOSYSTEM_CATALOG.docx](BROYHILLGOP_ECOSYSTEM_CATALOG.docx) — triggers, indexes, and brand-to-directory mapping.
  - E20 Brain Audit (E20_Brain_Audit_Report) — 22 deployment-critical functions, 22 populated tables, 28 empty tables; do not assume removal of existing functions/tables without explicit decision.

---

## 4. Key Conventions

- **person_id:** The single FK from all ecosystems to identity. Lives in `core.person_spine(person_id)`; norm and core tables reference it; never invent a second “person” key.
- **candidate_id / tenant_id:** Resolve via `core.candidate_committee_map` from committee_id (FEC/BOE). contribution_map must carry candidate_id and tenant_id for multi-tenant and ROI.
- **Eddie’s rules (from context):** Same-address block = street_number + last_name + zip5; preferred names by preponderance with VIP overrides; titles/salutations for officeholders; person_address for home/office/second home.
- **DataTrust / Acxiom:** Preserve `nc_datatrust` and `acxiom_consumer_data`; archive `datatrust_profiles` only if specified. DataTrust is Phase 4 enrichment (e.g. via rnc_regid), not the identity blocking key.

---

## 5. What Not to Do

- Do **not** seed `core.person_spine` from golden_records or person_master. Build from norm + resolution only.
- Do **not** run identity resolution until norm tables have `voter_ncid` and `email` (and `employer` for Pass 5); otherwise only Pass 3 runs and BOE resolution stays weak.
- Do **not** use a single blocking key (e.g. soundex(last_name)+zip5+first_initial) for identity; it fails for nickname/legal-name pairs (e.g. Ed/James).
- Do **not** move or drop existing public tables/schemas until the new core layer is validated and Eddie has approved.
- Do **not** run identity resolution or bulk ETL in the Supabase SQL editor for large tables; use Hetzner (or equivalent) with direct DB connection and no statement timeout.
- Do **not** create ecosystem-specific tables that duplicate person identity; all reference `core.person_spine`.
- Do **not** report resolution as a single weighted percentage; report BOE, FEC individual, and FEC party separately. BOE is NC's primary donor source.

---

## 6. References in This Repo

| Document | Purpose |
|----------|---------|
| [Claude-Cursor-ecosystems.md](../Claude-Cursor-ecosystems.md) | RFC-001: DDL, blocking, validation, migration sequence |
| [BROYHILLGOP_ECOSYSTEM_CATALOG.docx](../BROYHILLGOP_ECOSYSTEM_CATALOG.docx) | 58 ecosystems, triggers, indexes, brands (extract text via `textutil` if needed) |
| [BROYHILLGOP_COMPLETE_ECOSYSTEM_INVENTORY.md](BROYHILLGOP_COMPLETE_ECOSYSTEM_INVENTORY.md) | Ecosystem catalog (markdown) |
| [.cursorrules](../.cursorrules) | Inspinia/frontend and Supabase table/column names |
| E20_Brain_Audit_Report (external) | Deployment status: critical functions, populated/empty tables |
| [CLAUDE_10_QUESTIONS_RESPONSE_AND_CORRECTIVE_PLAN.md](CLAUDE_10_QUESTIONS_RESPONSE_AND_CORRECTIVE_PLAN.md) | 10 audit Q&A, Claude's admissions, corrective rebuild checklist |

---

*Follow these instructions for any database rebuild, identity resolution, or pipeline work so the platform stays aligned on rebuild-not-clean and RFC-001.*
