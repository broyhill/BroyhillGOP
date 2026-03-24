# BroyhillGOP Complete File Audit
**Date:** March 23, 2026 (updated from March 18 base)
**Scope:** GitHub, Google Drive, Dropbox, OneDrive
**Database state:** Active — post March 22-23 RNC voter & BOE matching sessions
**Prior version:** BROYHILLGOP_COMPLETE_FILE_AUDIT_Mar18_2026.md

---

## MARCH 22-23 SESSION CHANGES (Delta from Mar 18)

### New Files Pushed to GitHub (March 22-23)
| File | Path | Description |
|------|------|-------------|
| 2026-03-22_RNC-donor-id-BOE-update.md | sessions/ | RNC voter file download, 338,720 BOE rows matched (54.1%), voter_ncid type bug |
| 2026-03-23_FULL-DATABASE-AUDIT.md | sessions/ | 342-line complete database audit: all tables, sizes, connections, 21-step TODO |
| document-directory.html | docs/ | Updated interactive document search engine (35 docs, 8 categories) |
| BroyhillGOP-Perplexity-State-Config.md | docs/ | Perplexity Space system prompt for 7-layer blueprint generation |

### Infrastructure Changes (March 22-23)
- **Hetzner GEX44 (#2882435 / 5.9.99.109):** Docker 29.3.0 + Docker Compose v5.1.1 installed
- **E20 Brain Hub:** Deployed to /opt/broyhillgop/, running as `bgop_brain` container (4h uptime as of Mar 23)
- **Redis:** Running as `bgop_redis` container on port 6379
- **brain.py:** 144-line Python service connected to Claude API + Supabase + Redis, listening on bgop:events and bgop:triggers channels

### Database Changes (March 22-23)
| Table | Change | Details |
|-------|--------|---------|
| rnc_voter_staging | CREATED + LOADED | 7,708,542 rows — RNC voter file downloaded for rncid matching |
| nc_boe_donations_raw | PARTIAL UPDATE | 338,720/625,897 rows matched with rncid (54.1%); 287,177 rows need fuzzy pass |
| nc_boe_donations_raw | BUG IDENTIFIED | voter_ncid column is bigint — should be VARCHAR to match nc_voters.ncid |
| person_master | AUDITED | 7,660,622 rows — voter links populated, ALL donor links empty (boe_donor_id=0, fec_contributor_id=0, rnc_rncid=0) |
| datatrust_profiles | DROPPED (prior session) | 5.7 GB lost — was 69-col ETL layer; dropped by previous Claude session to recover space |

---

## 1. GITHUB — broyhill/BroyhillGOP (Main Repo)
**Visibility:** Public
**Last updated:** March 23, 2026
**Total tree entries:** ~2,560+ (198 folders + 2,558+ files)

### File Breakdown by Top-Level Folder

| Folder | Files | Notes |
|--------|------:|-------|
| frontend/ | 2,125 | Inspinia template (2,071), Candidate Portal (31), Command Center (4), Dashboard (1) |
| backend/python/ | 96 | Ecosystems (74), Integrations (11), Engines (4), Control Panel (2), Voice (2), API (1), Gateway (1) |
| database/ | 95 | Schemas (82), Migrations (9), Processor scripts (4) |
| ecosystems/ | 78 | Root-level ecosystem Python files (E00–E57 + variants + demos) |
| ECOSYSTEM_REPORTS/ | 48 | .docx reports for E01–E57 (with gaps at E13–E14, E23, E27, E29, E49–E50, E56) |
| docs/ | 23 | Handoff docs, deployment guides, PRE_ROLLBACK_SNAPSHOT_Mar18_2026.md, Perplexity State Config, updated document-directory.html |
| sessions/ | 5 | Session transcripts: Mar 20, Mar 21, Mar 22, Mar 23 x2 |
| scripts/ | 18 | Hetzner sync, deployment, utility scripts |
| candidates/ | 11 | Jeff Zenger: voice clone, audio, video, HTML template |
| e55_jeeva_clone/ | 11 | Autonomous Intelligence Agent |
| core/ | 8 | Auth, logging, security modules |
| e49_enhancement_patch/ | 8 | API Gateway, Storage, Workers, Frontend patches |
| scrapers/ | 8 | FEC scraper, NCBOE scraper, donor history builder, monitors |
| runpod/ | 5 | OmniAvatar ULTRA handler |
| api/ | 3 | Pixel tracking, identity resolver |
| config/ | 3 | deploy.sh, nexus.types.ts, supabase.env.template |
| .github/ | 1 | deploy-migration.yml |
| sql/ | 1 | Hetzner sync SQL |
| Root files | 17 | .cursorrules, README, index.html, vercel.json, 3 .docx specs, etc. |

### Session Transcripts (sessions/ folder)
| File | Description |
|------|-------------|
| 2026-03-20_NEXUS-donor-search-confession.md | NEXUS donor search session |
| 2026-03-21_DataTrust-Acxiom-Supabase-setup.md | DataTrust/Acxiom setup |
| 2026-03-22_RNC-donor-id-BOE-update.md | RNC voter file download + BOE 54.1% match |
| 2026-03-23_FULL-DATABASE-AUDIT.md | Complete 342-line DB audit with 21-step TODO |
| 2026-03-23_Hetzner-Docker-Claude-API.md | Hetzner Docker install + Brain Hub deployment |

---

## 2. GITHUB — Other Repositories

| Repository | Files | Visibility | Last Updated | Description |
|------------|------:|------------|--------------|-------------|
| broyhill/BroyhillGOP | 2,560+ | Public | 2026-03-23 | Main installation |
| broyhill/broyhillgop-index | 33 | Public | 2026-03-13 | Document search engine — 4,071 files indexed |
| broyhill/BroyhillGOP-ARCHIVE-DO-NOT-USE | — | Private | 2026-02-03 | Archive (DO NOT USE) |
| broyhill/donor-deduplication-supabase | 25 | Public | 2026-02-03 | Donor dedup/standardization |
| broyhill/runpod_omniavatar | 3 | Public | 2026-01-11 | OmniAvatar 14B video gen |
| broyhill/inspinia-template | — | Private | 2026-01-04 | Inspinia template source |
| broyhill/runpod_chatterbox | 5 | Public | 2025-12-27 | Voice cloning endpoint |
| broyhill/v0-broyhill-gop-le | — | Private | 2025-12-31 | v0 prototype |
| broyhill/v0-broyhill-gop-49 | — | Private | 2025-12-31 | v0 prototype |
| broyhill/v0-broyhill-gop | — | Private | 2025-12-31 | v0 prototype |
| broyhill/Xsellcast-CSR | — | Public | 2020-02-27 | Brand consultant demo (legacy) |

---

## 3. GOOGLE DRIVE (20 files found)

### Architecture & Platform Docs
| File | Type | Size | Modified |
|------|------|-----:|----------|
| ##1 BroyhillGOP-Document-Directory.html | HTML | 760KB | 2026-03-09 |
| BroyhillGOP-Document-Directory | Google Doc | 1KB | 2026-03-09 |
| 2026-02-18_Supabase-Schema-Inventory-2026-02-18.md | Markdown | 29KB | 2026-03-08 |
| BroyhillGOP-Master-Platform-Architecture-v3.docx | DOCX | 35KB | 2026-03-08 |
| BroyhillGOP-Complete-Platform-Architecture.docx | DOCX | 25KB | 2026-03-08 |
| BroyhillGOP-AI-Platform.md | Markdown | 7KB | 2026-03-08 |

### Audit & Session History
| File | Type | Size | Modified |
|------|------|-----:|----------|
| Jan17_BROYHILLGOP-COMPREHENSIVE-AUDIT-JAN17-2026.md | Markdown | 15KB | 2026-03-08 |
| 2026-02-12-session-transcript-fec-load-donor-linkage.txt | Text | 35KB | 2026-02-12 |

### Candidate & Ecosystem
| File | Type | Size | Modified |
|------|------|-----:|----------|
| 13-Candidate-Portal-Terms.docx | DOCX | 10KB | 2026-03-05 |
| ecosystem_24_candidate_portal_complete.py | Python | 43KB | 2026-03-02 |
| E26_CANDIDATE_PORTAL.docx | DOCX | 25KB | 2026-03-02 |
| 2026-02-17_BroyhillGOP-Candidate-Profile-Template-V2-3.md | Markdown | 17KB | 2026-03-08 |
| 2026-02-17_BroyhillGOP-Candidate-Profile-Template-V2-2.md | Markdown | 17KB | 2026-03-08 |
| 2025-12-07_BroyhillGOP-Automated-Approval-System.md | Markdown | 21KB | 2026-03-08 |

### Database & Pipeline
| File | Type | Size | Modified |
|------|------|-----:|----------|
| BroyhillGOP_Schema_Migration_v1.sql | SQL | 27KB | 2026-02-12 |
| Supabase-Schema-Inventory-2026-02-18.md | Markdown | 29KB | 2026-02-19 |
| Supabase schema for print campaign A_B testing.pdf | PDF | 379KB | 2026-02-21 |
| Ed Broyhill donor fec history _a-2026-02-23T23_14_19.numbers | Numbers | 501KB | 2026-02-24 |
| donor_merge_pipeline.py | Python | 74KB | 2026-01-06 |
| 2026-02-21_Perplexity-E11-Print-Ecosystem-Prompt copy 2.md | Markdown | 30KB | 2026-03-08 |

---

## 4. ONEDRIVE (15 files found)

### Platform Documentation
| File | Type | Size | Modified |
|------|------|-----:|----------|
| BroyhillGOP Supabase Audit - Recommendations & To-Do List.pdf | PDF | 123KB | 2026-02-13 |
| BroyhillGOP Supabase Audit - Recommendations & To-Do List.html | HTML | 1,061KB | 2026-02-13 |
| BROYHILLGOP_COMPLETE_PLATFORM_OVERVIEW.pdf | PDF | 350KB | 2025-12-12 |
| BroyhillGOP Functionality.docx | DOCX | 258KB | 2025-09-21 |

### Donor & Campaign Data
| File | Type | Size | Modified |
|------|------|-----:|----------|
| 2020_FEC_GOD_FILE.csv | CSV | 9,863KB | 2026-02-13 |
| BroyhillGOP Platform: Comprehensive Donor Behavior.pdf | PDF | 424KB | 2025-09-08 |
| BroyhillGOP Platform: Recalculated Daily Campaign.pdf | PDF | 501KB | 2025-09-08 |
| #1 COMPREHENSIVE REPORT OUTLINE: BroyhillGOP Advanced.pdf | PDF | 443KB | 2025-09-08 |
| COMPREHENSIVE REPORT OUTLINE: BroyhillGOP Advanced.pdf | PDF | 443KB | 2025-09-08 |

### Platform Proposals & Archives
| File | Type | Size | Modified |
|------|------|-----:|----------|
| BroyhillGOP Political Campaign Platform Proposal.pdf | PDF | 677KB | 2025-09-08 |
| BroyhillGOP Platform Implementation: Revised Complete.pdf | PDF | 539KB | 2025-09-08 |
| BroyhillGOP-main (1).zip | ZIP | 24,300KB | 2025-09-07 |
| BroyhillGOP.json | JSON | 27KB | 2025-06-03 |

---

## 5. DROPBOX (3 files found)

| File | Type | Size | Modified |
|------|------|-----:|----------|
| republican donor cells.xls | Excel | 862KB | 2026-02-28 |
| Supabase-Schema-Tables-1-3.sql | SQL | 20KB | 2025-10-26 |
| (S3 URL artifact — PDF) | PDF | 87KB | 2025-10-27 |

Location: `BroyhillGOP Final Presentation/` folder

---

## 6. HETZNER SERVER (as of March 23, 2026)

**Server:** GEX44 #2882435 — 5.9.99.109 (Ubuntu 22.04)
**SSH:** `ssh -i ~/.ssh/id_ed25519_hetzner root@5.9.99.109`

| Service | Status | Details |
|---------|--------|---------|
| Docker | ✅ Running | v29.3.0 |
| Docker Compose | ✅ Running | v5.1.1 |
| bgop_redis | ✅ Up | Redis 7-alpine, port 6379 |
| bgop_brain | ✅ Up | Python 3.11, E20 Brain Hub |
| Brain connection | ✅ Connected | Listening on bgop:events + bgop:triggers |
| /opt/broyhillgop/ | ✅ Exists | docker-compose.yml, brain.py, .env |

---

## GRAND TOTALS

| Source | Files | Key Content |
|--------|------:|-------------|
| GitHub (BroyhillGOP main) | 2,560+ | Full platform codebase + session transcripts |
| GitHub (other repos) | 66+ | Index, dedup, RunPod, templates |
| Google Drive | 20 | Architecture docs, schemas, pipelines, transcripts |
| OneDrive | 15 | Audits, donor data, proposals, platform overview |
| Dropbox | 3 | Donor spreadsheet, schema SQL |
| **TOTAL** | **~2,664+** | |

---

## FLAGS & RECOMMENDATIONS

### ⚠️ Critical Database Issues (as of March 23)
1. **voter_ncid type mismatch** — nc_boe_donations_raw.voter_ncid is bigint; must be VARCHAR to join nc_voters.ncid
2. **BOE fuzzy match incomplete** — 287,177 of 625,897 BOE rows (45.9%) have no rncid; need fuzzy name+zip pass
3. **person_master donor linkage = 0** — boe_donor_id, fec_contributor_id, rnc_rncid all null for all 7.66M rows
4. **datatrust_profiles DROPPED** — 5.7 GB, 69-col ETL layer gone; raw datatrust (251 cols) connects directly to person_master (43 cols) with no clean intermediate layer
5. **fec_committee_master_staging** has 35,521 rows; fec_committees only has 60 — staging never promoted
6. **golden_record_clusters** has only 3 rows — identity clustering never run at scale

### Duplicates to Clean Up
1. **database/schemas/** has 14+ files with version suffixes (" 2.sql", " 4.sql", " 5.sql") — should be archived or removed
2. **Ecosystem duplication** — backend/python/ecosystems/ (74 files) vs. root ecosystems/ (78 files) have overlapping but not identical contents
3. **OneDrive** has duplicate comprehensive reports
4. **Google Drive** has two copies of Supabase-Schema-Inventory

### Files Unique to Cloud Storage (not in GitHub)
- `donor_merge_pipeline.py` (74KB) — Google Drive only ⚠️ Should be committed
- `2020_FEC_GOD_FILE.csv` (9.8MB) — OneDrive only
- `republican donor cells.xls` (862KB) — Dropbox only
- `Ed Broyhill donor fec history.numbers` (501KB) — Google Drive only
- `BroyhillGOP_Schema_Migration_v1.sql` (27KB) — Google Drive only ⚠️ Should be committed

### 21-Step Database Completion Plan

**Phase 1 — Data Type & Join Fixes**
1. Fix voter_ncid bigint → VARCHAR on nc_boe_donations_raw
2. Re-run BOE exact match pass after type fix
3. Run BOE fuzzy match on 287,177 remaining rows (name + zip5)

**Phase 2 — Donor Linkage**
4. Populate boe_donor_id on person_master
5. Populate fec_contributor_id on person_master
6. Populate rnc_rncid on person_master
7. Set is_donor flag based on linked donations

**Phase 3 — Staging Promotion**
8. Promote fec_committee_master_staging → fec_committees
9. Rebuild or restore datatrust_profiles (69-col ETL layer)
10. Validate DataTrust ↔ nc_voters join coverage

**Phase 4 — Identity Resolution**
11. Run golden_record_clusters at scale
12. Merge duplicate person_master rows
13. Assign canonical person_id across all donation tables

**Phase 5 — Ecosystem Activation**
14. Activate E01 — Donor Intelligence
15. Activate E07 — Volunteer Management
16. Activate E11 — Budget & Print
17. Activate E19 — Social Media
18. Activate E30 — Email
19. Activate E31 — SMS
20. Activate E36 — GOTV
21. Activate E52 — Contact Intelligence Engine
