# BroyhillGOP Master Directory Index
## Complete Inventory of All Project Artifacts
**Generated:** March 18, 2026 | **Platform:** BroyhillGOP Fundraising Microsegmentation Platform
**Purpose:** 57 Campaign Ecosystem fundraising optimization via donor microsegmentation

---

## SECTION 1: ECOSYSTEM REPORTS (48 DOCX Files)
**Location:** `/BroyhillGOP-CURSOR/ECOSYSTEM_REPORTS/`

Each ecosystem is a modular campaign component with its own 7-layer blueprint architecture.

| File | Ecosystem | Subjects Covered |
|------|-----------|-----------------|
| E01_DONOR_INTELLIGENCE.docx | Donor Intelligence | Donor profiling, scoring, segmentation, 8 Republican archetypes, giving capacity, wealth screening, donor lifecycle |
| E02_DONATION_PROCESSING.docx | Donation Processing | Payment processing, WinRed integration, FEC compliance, receipt generation, recurring gifts |
| E03_CANDIDATE_MANAGEMENT.docx | Candidate Management | Candidate profiles, race tracking, committee assignments, filing deadlines, ballot positioning |
| E04_ACTIVIST_NETWORK.docx | Activist Network | Grassroots organizing, activist scoring, network mapping, mobilization triggers |
| E05_VOLUNTEER_MANAGEMENT.docx | Volunteer Management | Volunteer recruitment, scheduling, task assignment, hours tracking, recognition programs |
| E06_ANALYTICS_ENGINE.docx | Analytics Engine | Data warehouse analytics, KPI dashboards, predictive modeling, trend analysis |
| E07_ISSUE_TRACKING.docx | Issue Tracking | Policy issue monitoring, voter sentiment, issue-candidate alignment, hot-button tracking |
| E08_COMMUNICATIONS_LIBRARY.docx | Communications Library | Template management, message versioning, multi-channel content repository |
| E09_CONTENT_CREATION_AI.docx | Content Creation AI | AI-generated content, copy variations, tone matching, A/B headline generation |
| E10_COMPLIANCE.docx | Compliance | FEC reporting, state filing, contribution limits, disclosure rules, audit trails |
| E11_BUDGET.docx | Budget Management | Campaign budgeting, expense tracking, burn rate, allocation optimization |
| E12_CAMPAIGN_OPERATIONS.docx | Campaign Operations | Field operations, canvassing routes, GOTV planning, precinct targeting |
| E15_CONTACT_MANAGEMENT.docx | Contact Management | CRM contact records, merge/dedup, contact enrichment, relationship mapping |
| E16_TV_RADIO_BROADCAST.docx | TV/Radio Broadcast | Media buying, ad placement, broadcast scheduling, market targeting |
| E17_RINGLESS_VOICEMAIL.docx | Ringless Voicemail | RVM delivery, DropCowboy integration, message scripting, compliance |
| E19_SOCIAL_MEDIA.docx | Social Media | Platform management, post scheduling, engagement tracking, audience targeting |
| E20_INTELLIGENCE_BRAIN.docx | Intelligence Brain | Central AI orchestrator, cross-ecosystem data fusion, predictive analytics, decision engine |
| E21_MACHINE_LEARNING.docx | Machine Learning | Clustering algorithms, donor propensity models, churn prediction, lookalike audiences |
| E22_AB_TESTING.docx | A/B Testing | Experiment design, statistical significance, multi-variate testing, conversion optimization |
| E24_DONOR_PORTAL.docx | Donor Portal | Self-service donor dashboard, giving history, tax receipts, pledge management |
| E25_VOLUNTEER_PORTAL.docx | Volunteer Portal | Volunteer self-service, shift signup, training modules, leaderboards |
| E26_CANDIDATE_PORTAL.docx | Candidate Portal | Candidate dashboard, fundraising progress, endorsement tracking |
| E28_FINANCIAL_MANAGEMENT.docx | Financial Management | Treasury operations, fund accounting, FEC disbursement tracking, cash flow |
| E30_EMAIL_CAMPAIGNS.docx | Email Campaigns | Email marketing, list segmentation, drip sequences, deliverability, open/click tracking |
| E31_SMS_MARKETING.docx | SMS Marketing | Text campaigns, opt-in management, keyword triggers, P2P texting |
| E32_PHONE_CALL_CENTER.docx | Phone Call Center | Phone banking, predictive dialer, call scripting, disposition tracking |
| E33_DIRECT_MAIL.docx | Direct Mail | Print production, variable data, postal optimization, response tracking |
| E34_EVENTS.docx | Events | Fundraising events, ticketing, venue management, event ROI |
| E35_UNIFIED_INBOX.docx | Unified Inbox | Cross-channel message aggregation, response routing, SLA tracking |
| E36_MESSENGER.docx | Messenger | Chat integration, Facebook Messenger, WhatsApp, chatbot automation |
| E37_EVENT_MANAGEMENT.docx | Event Management | Event lifecycle, registration, check-in, post-event follow-up |
| E38_FIELD_OPERATIONS.docx | Field Operations | Door-to-door canvassing, turf cutting, walk lists, GPS tracking |
| E39_P2P_FUNDRAISING.docx | P2P Fundraising | Peer-to-peer campaigns, fundraiser pages, social sharing, team goals |
| E40_AUTOMATION_CONTROL.docx | Automation Control | Workflow automation, trigger rules, multi-step sequences, conditional logic |
| E41_CAMPAIGN_BUILDER.docx | Campaign Builder | Visual campaign designer, multi-channel orchestration, journey mapping |
| E42_NEWS_INTELLIGENCE.docx | News Intelligence | Media monitoring, sentiment analysis, news alerts, opposition research feeds |
| E43_ADVOCACY.docx | Advocacy Tools | Petition management, legislative alerts, constituent action center |
| E44_VENDOR_MANAGEMENT.docx | Vendor Management | Vendor contracts, compliance verification, performance scoring, security audit |
| E45_VIDEO_STUDIO.docx | Video Studio | Video production, AI editing, thumbnail generation, platform distribution |
| E46_BROADCAST_HUB.docx | Broadcast Hub | Live streaming, webinar management, multi-platform broadcasting |
| E47_SCRIPT_GENERATOR.docx | Script Generator | AI call scripts, talking points, objection handling, personalization tokens |
| E48_COMMUNICATION_DNA.docx | Communication DNA | Communication style profiling, channel preference, optimal send time, fatigue management |
| E51_PRIME_COMMAND.docx | Prime Command | Master control panel, ecosystem status dashboard, deployment orchestration |
| E52_CONTACT_INTELLIGENCE.docx | Contact Intelligence | Contact enrichment, social graph mapping, influence scoring, relationship strength |
| E53_DOCUMENT_GENERATION.docx | Document Generation | Automated document creation, mail merge, FEC form generation, PDF assembly |
| E54_CALENDAR.docx | Calendar & Scheduling | Campaign calendar, filing deadlines, event scheduling, resource allocation |
| E55_API_GATEWAY.docx | API Gateway | External integrations, rate limiting, authentication, webhook management |
| E57_MESSAGING_CENTER.docx | Messaging Center | Central message routing, template selection, channel optimization, delivery tracking |

---

## SECTION 2: SQL MIGRATIONS (51 Files)
**Location:** `/BroyhillGOP-CURSOR/database/migrations/`

### Data Infrastructure & Schema
| File | Purpose | Tables Affected |
|------|---------|----------------|
| 051_NEXUS_SOCIAL_EXTENSION.sql | Social media data extension for Nexus brain | nexus_social_* |
| 052_NEXUS_HARVEST_ENRICHMENT.sql | Harvest enrichment pipeline for Nexus | nexus_harvest_* |
| 053_NEXUS_PLATFORM_INTEGRATION.sql | Platform integration tables for Nexus | nexus_platform_* |
### Candidate & Committee Mapping
| File | Purpose | Tables Affected |
|------|---------|----------------|
| 054_CANDIDATE_COMMITTEE_MAPPING.sql | Maps candidates to their FEC committees | candidate_committee_map |
| 055_DONATION_SEARCH_VIEW.sql | Searchable donation view across all sources | donation_search_view |

### DataTrust & Voter Integration
| File | Purpose | Tables Affected |
|------|---------|----------------|
| 056_VOTER_PROFILE_DATATRUST.sql | DataTrust voter profile import schema | datatrust_profiles |
| 057_DONOR_ANALYSIS_VIEW.sql | Analytical view joining donors + voter data | donor_analysis_view |
| 058_FEC_VOTER_MATCHES.sql | FEC-to-voter matching logic | fec_voter_matches |
| 059_FEC_SEPARATE_COMMITTEES.sql | Separate committee donation tracking | fec_committee_donations |
| 060_DATATRUST_DONOR_CANDIDATE_AFFINITY.sql | Donor-candidate affinity scoring | datatrust_affinity |
| 061_DATATRUST_AFFINITY_EXTENDED.sql | Extended affinity with multi-cycle data | datatrust_affinity_ext |
| 062_DATATRUST_FULL_2500_AFFINITY.sql | Full 2500-donor affinity matrix | datatrust_full_affinity |

### NC BOE Ingestion & Normalization
| File | Purpose | Tables Affected |
|------|---------|----------------|
| 063_NCBOE_GENERAL_FUND_INGESTION.sql | NC Board of Elections general fund import | ncboe_general_fund |
| 064_NCBOE_GENERAL_TYPE_RENORMALIZE.sql | Re-normalize BOE donation types | ncboe_normalized |

### Identity Resolution Pipeline (Phase 0-4)
| File | Purpose | Tables Affected |
|------|---------|----------------|
| 065_IDENTITY_RESOLUTION_OVERHAUL_PHASE0.sql | Phase 0: Schema setup for identity resolution | staging.*, core.* |
| 066_PHASE1_SPINE_DEDUP.sql | Phase 1: Duplicate detection on person_spine | core.person_spine |
| 067_PHASE1B_EXECUTE_MERGES.sql | Phase 1B: Execute merge operations | core.person_spine, merge_log |
| 068_PHASE2_VOTER_MATCHING.sql | Phase 2: Match spine records to voter file | core.person_spine, voter_match |
| 069_PHASE3_FEC_DONATIONS_MAPPING.sql | Phase 3: Map FEC donations to spine | fec_donations, contribution_map |
| 070_PHASE4_BRIDGE_AND_AGGREGATES.sql | Phase 4: Build bridge tables + aggregates | core.contribution_map, spine aggregates |
### Identity Resolution v2 (Revised Pipeline)
| File | Purpose | Tables Affected |
|------|---------|----------------|
| 071_identity_rollup_revised.sql | Revised identity rollup with improved matching | core.person_spine |
| 075_fec_donor_person_matching.sql | FEC donor-to-person matching | fec_donations, person_spine |
| 076_golden_record_spine_bridge.sql | Bridge golden records to spine | golden_record_bridge |
| 077_populate_contribution_map.sql | Populate contribution map from all sources | core.contribution_map |
| 078_recalculate_spine_aggregates.sql | Recalculate donation aggregates on spine | core.person_spine |
| 079_pass2_identity_resolution.sql | Second-pass identity resolution | core.person_spine |
| 080_spine_dedup_five_pass.sql | 5-pass deduplication strategy | core.person_spine |
| 080b_repair_golden_bridges.sql | Repair broken golden record bridges | golden_record_bridge |
| 080c_rebuild_fec_from_raw.sql | Rebuild FEC donations from raw data | public.fec_donations |
| 081_normalize_fec_donations.sql | Normalize FEC donation fields | public.fec_donations |

### FEC-to-Spine Matching (Mar 17, 2026 — Current Session)
| File | Purpose | Tables Affected | Results |
|------|---------|----------------|---------|
| 083_match_fec_to_spine_v3.sql | 3-tier FEC→spine matching (PRODUCTION) | fec_donations.person_id | 2,247,173 linked (86.5%) |
| 084_match_party_to_spine.sql | Party committee donations→spine matching | fec_party_committee_donations.person_id | 1,264,467 linked (72.9%) |
| 085_rebuild_contribution_map.sql | Rebuild contribution_map + spine aggregates | core.contribution_map, core.person_spine | 3,109,705 total rows |

### Supporting Migration Files
| File | Purpose |
|------|---------|
| 2024_12_enhancement_migration.sql | December 2024 schema enhancements |
| SPI_office_patch.sql | Office field patches |
| broyhillgop_office_heatmap_extension.sql | Office heatmap data extension |
| contact_enrichment_to_golden_matching.sql | Contact enrichment bridge to golden records |
| donor_sic_classification_engine.sql | SIC code classification for donor employers |
| judicial_offices_patch.sql | Judicial office schema patches |
| ncga_committee_industry_naics.sql | NCGA committee-to-industry NAICS mapping |
| ncga_legislator_committee_matrix.sql | Legislator-committee assignment matrix |

---

## SECTION 3: PYTHON CODE INVENTORY (134+ Files)

### 3A. Ecosystem Backend Modules (73 files)
**Location:** `/backend/python/ecosystems/`

Each file implements one ecosystem's backend logic — API endpoints, data models, and business rules.

| File | Ecosystem | Key Functions |
|------|-----------|--------------|
| ecosystem_00_datahub_complete.py | DataHub | Central data orchestration, cross-ecosystem data routing |
| ecosystem_01_donor_intelligence_complete.py | E01 Donor Intelligence | Donor scoring, segmentation, wealth screening, archetypes |
| ecosystem_01_dual_grading_update.py | E01 Grading Update | Dual-axis grading (capacity × propensity) |
| ecosystem_02_donation_processing_complete.py | E02 Donations | Payment processing, WinRed webhooks, receipt generation |
| ecosystem_03_candidate_profiles_complete.py | E03 Candidates | Candidate CRUD, race tracking, committee links |
| ecosystem_04_activist_network_complete.py | E04 Activists | Network graph, mobilization scoring |
| ecosystem_05_volunteer_management_complete.py | E05 Volunteers | Shift scheduling, hours tracking, recognition |
| ecosystem_06_analytics_engine_complete.py | E06 Analytics | KPI computation, dashboard data feeds |
| ecosystem_07_issue_tracking_complete.py | E07 Issues | Issue CRUD, sentiment aggregation |
| ecosystem_08_communications_library_complete.py | E08 Comms Library | Template CRUD, version control |
| ecosystem_09_content_creation_ai_complete.py | E09 AI Content | LLM integration, copy generation, tone matching |
| ecosystem_10_compliance_manager_complete.py | E10 Compliance | FEC validation, filing automation |
| ecosystem_11_budget_management.py | E11 Budget | Budget CRUD, burn rate calculation |
| ecosystem_12_campaign_operations_complete.py | E12 Campaign Ops | Field ops routing, GOTV targeting |
| ecosystem_13_ai_hub_complete.py | E13 AI Hub | Central AI model registry, inference routing |
| ecosystem_14_print_production_complete.py | E14 Print | Print job management, VDP templates |
| ecosystem_15_contact_directory_complete.py | E15 Contacts | Contact CRUD, merge/dedup UI |
| ecosystem_16_tv_radio_complete.py | E16 TV/Radio | Media buy management, spot scheduling |
| ecosystem_16b_voice_synthesis_ULTRA.py | E16b Voice | Ultra voice synthesis (RunPod GPU) |
| ecosystem_17_rvm_complete.py | E17 RVM | Ringless voicemail delivery, DropCowboy API |
| ecosystem_18_print_advertising_complete.py | E18 Print Ads | Print ad design, placement tracking |
| ecosystem_18_vdp_composition_engine_complete.py | E18 VDP | Variable data print composition |
| ecosystem_19_social_media_enhanced.py | E19 Social | Social post scheduling, engagement tracking |
| ecosystem_20_intelligence_brain_complete.py | E20 Brain | Central AI orchestrator, cross-ecosystem fusion, decision engine |
| ecosystem_21_ml_clustering_complete.py | E21 ML | K-means clustering, donor segments, lookalike models |
| ecosystem_22_ab_testing_engine_complete.py | E22 A/B Test | Experiment framework, statistical significance, Bayesian methods |
| ecosystem_23_creative_asset_3d_engine_complete.py | E23 3D Assets | 3D creative asset generation engine |
| ecosystem_24_candidate_portal_complete.py | E24 Candidate Portal | Candidate self-service dashboard |
| ecosystem_25_donor_portal_complete.py | E25 Donor Portal | Donor self-service, giving history, pledges |
| ecosystem_26_volunteer_portal_complete.py | E26 Volunteer Portal | Volunteer self-service, shift signup |
| ecosystem_27_realtime_dashboard_complete.py | E27 Realtime | WebSocket dashboards, live data feeds |
| ecosystem_28_financial_dashboard_complete.py | E28 Financial | Treasury dashboard, cash flow visualization |
| ecosystem_29_analytics_dashboard_complete.py | E29 Analytics Dashboard | Cross-ecosystem analytics visualization |
| ecosystem_30_email_complete.py | E30 Email | Email campaign engine, list management, deliverability |
| ecosystem_31_sms_complete.py | E31 SMS | SMS campaign engine, opt-in/out, keyword triggers |
| ecosystem_32_phone_banking_complete.py | E32 Phone | Predictive dialer, call scripting, dispositions |
| ecosystem_33_direct_mail_complete.py | E33 Direct Mail | Print production, postal optimization, USPS integration |
| ecosystem_34_events_complete.py | E34 Events | Event management, ticketing, ROI tracking |
| ecosystem_35_interactive_comm_hub_complete.py | E35 Comm Hub | Unified inbox, response routing |
| ecosystem_36_messenger_integration_complete.py | E36 Messenger | Chat platform integrations |
| ecosystem_37_event_management_complete.py | E37 Events Mgmt | Full event lifecycle management |
| ecosystem_38_volunteer_coordination_complete.py | E38 Field Ops | Canvassing routes, turf management, GPS |
| ecosystem_39_p2p_fundraising_complete.py | E39 P2P | Peer fundraiser pages, social sharing |
| ecosystem_40_automation_control_panel_complete.py | E40 Automation | Workflow builder, trigger rules, conditional logic |
| ecosystem_41_campaign_builder_complete.py | E41 Campaign Builder | Visual journey designer, multi-channel orchestration |
| ecosystem_42_news_intelligence_complete.py | E42 News Intel | Media monitoring, sentiment analysis, alerts |
| ecosystem_43_advocacy_tools_complete.py | E43 Advocacy | Petition management, legislative action center |
| ecosystem_44_vendor_compliance_security_complete.py | E44 Vendor | Vendor contracts, compliance, security audit |
| ecosystem_45_video_studio_complete.py | E45 Video | AI video editing, production pipeline |
| ecosystem_46_broadcast_hub_complete.py | E46 Broadcast | Live streaming, multi-platform broadcast |
| ecosystem_47_ai_script_generator_complete.py | E47 Scripts | AI call scripts, talking points generation |
| ecosystem_48_communication_dna_complete.py | E48 Comm DNA | Communication style profiling, channel preference |
| ecosystem_49_interview_system_complete.py | E49 Interviews | Interview scheduling, scoring, feedback |
| ecosystem_50_gpu_orchestrator_complete.py | E50 GPU | RunPod GPU job orchestration |
| ecosystem_51_nexus_complete.py | E51 Nexus | Master control, ecosystem status, deployment |
| ecosystem_52_messaging_center_complete.py | E52 Messaging | Central message routing, template selection |
| ecosystem_53_document_generation_complete.py | E53 Doc Gen | Automated document creation, mail merge |
| ecosystem_54_calendar_scheduling_complete.py | E54 Calendar | Campaign calendar, deadline tracking |
| ecosystem_55_api_gateway_complete.py | E55 API | External integrations, rate limiting, auth |
| ecosystem_demo_controller_complete.py | Demo Controller | Demo mode orchestration |
| ecosystem_demo_video_production_complete.py | Demo Video | Demo video generation |
| event_timing_discipline.py | Event Timing | Event timing rules and discipline |
| nc_office_context_mapping.py | NC Office Map | NC municipal office → ecosystem mapping |
| donor_cultivation_intelligence.py | Donor Cultivation | Donor cultivation sequence intelligence |
| E20_volunteer_integration_update.py | E20 Vol Update | Volunteer data integration into Brain |
| december_2024_integration.py | Dec 2024 | December 2024 integration patch |
| ecosystem_19_personalization_engine.py | E19 Personalization | Content personalization engine |

### 3B. Integration Layer (11 files)
**Location:** `/backend/python/integrations/`

| File | Purpose |
|------|---------|
| BROYHILLGOP_MASTER_INTEGRATION_COMPLETE.py | Master integration orchestrator — connects all ecosystems |
| DEPLOY_ALL_ECOSYSTEMS.py | Deployment script for all 57 ecosystems |
| DEPLOY_MARKETO_CLONE.py | Marketo-equivalent marketing automation deployment |
| ECOSYSTEM_INTEGRATION_ARCHITECTURE.py | Architecture definitions for ecosystem interconnections |
| MASTER_ECOSYSTEM_ORCHESTRATOR.py | Top-level orchestrator for ecosystem lifecycle |
| calendar_hub_integration.py | Calendar hub cross-ecosystem integration |
| datatrust_api_client.py | DataTrust RNC API client (voter file access) |
| master_communication_orchestrator.py | Cross-channel communication routing |
| runpod_voice_cloning.py | RunPod GPU voice cloning pipeline |
| telecom_bandwidth_provider.py | Bandwidth.com telecom provider integration |
| telecom_dropcowboy_rvm_provider.py | DropCowboy RVM provider integration |

### 3C. Engine Layer (4 files)
**Location:** `/backend/python/engines/`

| File | Purpose |
|------|---------|
| nexus_brain_engine.py | Core Nexus AI brain — decision engine, cross-ecosystem intelligence |
| nexus_harvest_engine.py | Data harvesting engine — enrichment pipeline |
| nexus_persona_engine.py | Donor persona modeling engine — archetype classification |
| test_voice.aiff | Voice synthesis test audio file |

### 3D. Control Panel & API (3 files)
**Location:** `/backend/python/control_panel/` and `/backend/python/api/`

| File | Purpose |
|------|---------|
| master_control_panel.py | Master control panel — ecosystem status, health monitoring |
| control_panel_enhanced.py | Enhanced control panel with drill-down analytics |
| campaign_wizard_api.py | Campaign wizard API — step-by-step campaign creation |

### 3E. Pipeline Scripts (22 files)
**Location:** `/pipeline/`

| File | Purpose |
|------|---------|
| db.py | Database connection utilities (Supabase PostgreSQL) |
| ingest.py | Main ingestion orchestrator |
| dedup.py | Deduplication logic |
| fec_raw_import.py | FEC raw file import (CSV → staging) |
| fec_norm_populate.py | FEC normalization and population |
| identity_resolution.py | Identity resolution engine |
| norm_etl_ncboe.py | NC BOE normalization ETL |
| norm_gate.py | Normalization quality gate checks |
| nc_boe_voter_match.py | NC BOE → voter file matching |
| nc_boe_pre_handoff_check.py | Pre-handoff quality check for NC BOE |
| import_ncboe_committee_registry.py | NC BOE committee registry import |
| audit_ncboe_status.py | NC BOE pipeline audit tool |
| run_seed.py | Database seeding script |
| schema_check.py | Schema validation checks |
| index_check.py | Index existence validation |
| test_2015_2016.py | Test suite for 2015-2016 FEC data |
| nc_boe_ddl.sql | NC BOE DDL (table creation) |
| nc_boe_ddl_rollback.sql | NC BOE DDL rollback |
| nc_boe_dedup_fixes.sql | NC BOE dedup fix scripts |
| seed_fec_2015_2016.sql | FEC 2015-2016 seed data |
| seed_nc_boe.sql | NC BOE seed data |
| __init__.py | Package init |

### 3F. Operational Scripts (37 files)
**Location:** `/scripts/`

| File | Purpose |
|------|---------|
| analyze_donor_percentiles.py | Donor percentile distribution analysis |
| audit_top100_home_vs_business_address.py | Top 100 donor address audit (home vs business) |
| batch_grade_donors.py | Batch donor grading engine |
| build_contributions.py | Build contribution map from raw sources |
| build_donor_golden_records.py | Golden record construction |
| compose_thank_you_video.py | AI thank-you video composition |
| compose_video_local.py | Local video composition pipeline |
| db_conn.py | Database connection helper |
| fec_2015_2016_filter_clean.py | FEC 2015-2016 filter and clean |
| fec_filter_pipeline.py | FEC filtering pipeline |
| fec_filtered_extract.py | FEC filtered data extraction |
| fec_worker.py | FEC parallel processing worker |
| geocodio_csv_enricher.py | Geocodio CSV batch enrichment |
| geocodio_enrichment.py | Geocodio API enrichment pipeline |
| import_all_donations.py | Master donation import across all sources |
| import_ncboe_raw.py | NC BOE raw file import |
| import_ncgop_staging.py | NCGOP staging table import |
| import_watchdog.py | File system watchdog for auto-import |
| launch_fec_workers.py | FEC parallel worker launcher |
| load_general_fund_csv.py | General fund CSV loader |
| loader_fec.py | FEC data loader |
| loader_final.py | Final-stage data loader |
| match_donations_to_donors.py | Donation-to-donor matching engine |
| match_ncgop_to_voters.py | NCGOP-to-voter file matching |
| normalize_ncboe.py | NC BOE normalization |
| repair_candidate_attribution.py | Candidate attribution repair script |
| run_pipeline.sh | Master pipeline runner (bash) |
| unified_loader.py | Unified data loader v1 |
| unified_loader_v2.py | Unified data loader v2 (current) |
| usps_address_enrichment.py | USPS address standardization |
| utils.py | Shared utility functions |
| validate_source_files.py | Source file validation |
| verify_golden_record_quality.sql | Golden record quality verification |
| verify_schema_before_run.sql | Pre-run schema verification |

### 3G. Search & Indexing Tools (2 files)
**Location:** `/BroyhillGOP-CURSOR/` root

| File | Purpose |
|------|---------|
| ecosystem_search_engine.py | Ecosystem document search engine — scans .md files, outputs JSON index. **NEEDS FIX: expand to scan .docx, .sql, .py, .xlsx, .numbers, .html, .json** |
| ecosystem_search_results.json | Search engine output — indexed document metadata |

---

## SECTION 4: DOCUMENTATION & ARCHITECTURE (85+ Files)

### 4A. Startup & Governance (MUST-READ)
**Location:** `/docs/`

| File | Purpose | Priority |
|------|---------|----------|
| CLAUDE_INSTRUCTIONS_RFC001_REBUILD.md | **RFC-001 STARTUP SCRIPT** — MUST be read before ANY database work | CRITICAL |
| 00_READ_FIRST_MANDATORY_INSTRUCTIONS.md | Mandatory instructions for any new session | CRITICAL |
| QUICK_START_FOR_NEW_SESSION.md | Quick-start checklist for new AI sessions | HIGH |
| 00_MASTER_HANDOFF_COMPLETE.md | Master handoff document — full platform state | HIGH |
| DATABASE_ARCHITECTURE_RULES.md | Database architecture rules and constraints | HIGH |
| CLAUDE_DEPLOYMENT_GATE.md | Deployment gate checklist | HIGH |
| RFC-001-ARCHITECTURE-REVIEW.md | RFC-001 architecture review findings | HIGH |

### 4B. Database & Schema Documentation
| File | Purpose |
|------|---------|
| BroyhillGOP-Database-Schema-Spec-v1.docx | Full database schema specification v1 |
| BROYHILLGOP_DATABASE_INCIDENT_TRANSCRIPT.docx | Database incident post-mortem |
| CANONICAL_TABLES_AUDIT.md | Audit of canonical/staging tables |
| DEDUP_IDENTITY_MATCHING_REFERENCE.md | Identity matching algorithm reference |
| IDENTITY_RESOLUTION_CHECKPOINT_AFTER_066.md | Checkpoint after migration 066 |
| IDENTITY_RESOLUTION_OVERHAUL_EXECUTION_PLAN.md | Full identity resolution execution plan |
| MATCHING_LOGIC_AUDIT_COMPLETE.md | Complete matching logic audit |
| NC_VOTER_FILE_SCHEMA.md | NC voter file schema reference |
| NCBOE_SCHEMA_REFERENCE.md | NC BOE data schema reference |
| PERSON_MASTER_SCHEMA.sql | Person master table DDL |
| PRE_ROLLBACK_SNAPSHOT_Mar18_2026.md | Pre-rollback database snapshot |
| Schema discovery results.md | Schema discovery audit results |

### 4C. Pipeline & Ingestion Documentation
| File | Purpose |
|------|---------|
| INGESTION_PIPELINE_MASTER_PLAN.md | Master ingestion pipeline plan |
| NCBOE_INGESTION_PIPELINE_MASTER_PLAN_V2.md | NC BOE ingestion v2 plan |
| NCBOE_PIPELINE_AUDIT_REPORT.md | NC BOE pipeline audit results |
| NCBOE_PIPELINE_VERIFICATION_SNIPPETS.md | Pipeline verification SQL snippets |
| NCBOE_TASK1_2_3_REVISED_PLAN.md | NC BOE tasks 1-3 revised plan |
| PIPELINE_DEDUP_ARCHITECTURE.md | Dedup architecture specification |
| PIPELINE_INSTRUCTIONS.md | Pipeline execution instructions |
| PIPELINE_SETUP_FRESH_DB.md | Fresh database pipeline setup |
| PERPLEXITY_FEC_DONOR_MATCHING_PLAN.md | FEC donor matching plan |
| PERPLEXITY_DONOR_ANALYSIS_INSTALL_PLAN.md | Donor analysis installation plan |

### 4D. Ecosystem Architecture & Catalogs
| File | Purpose |
|------|---------|
| BROYHILLGOP_ECOSYSTEM_CATALOG.docx | Complete ecosystem catalog (57 ecosystems) |
| BROYHILLGOP_COMPLETE_ECOSYSTEM_INVENTORY.md | Full ecosystem inventory |
| BROYHILLGOP_ECOSYSTEM_COMPLETE_DETAIL.md | Detailed ecosystem specifications |
| BROYHILLGOP_ECOSYSTEM_TO_INSPINIA_BUILD_PLAN.md | Ecosystem → Inspinia template build plan |
| COMPLETE_ECOSYSTEM_REFERENCE.md | Complete ecosystem cross-reference |
| README_COMPLETE_49_ECOSYSTEMS.md | 49-ecosystem README |
| BROYHILLGOP_FRONTEND_ORCHESTRATION.docx | Frontend orchestration architecture |
| BROYHILLGOP_CANDIDATE_UX_SPECIFICATION.docx | Candidate UX specification |
| INSPINIA_TEMPLATE_SPECIFICATION.docx | Inspinia admin template specification |
| BROYHILLGOP_FORMAL_DEVELOPMENT_PROCESS.md | Formal development process |

### 4E. Donor Analysis & Intelligence
| File | Purpose |
|------|---------|
| BOLIEK_DONOR_ANALYSIS_ANSWERS.md | Boliek donor analysis Q&A |
| JAY_FAISON_DATABASE_AUDIT.md | Jay Faison database audit |
| DONOR_RANGES_AND_LIMITS_RULES.md | Donation ranges and FEC limit rules |
| DONOR_SELECTION_ALGORITHM_SPEC.md | Donor selection algorithm specification |
| DATATRUST_DONOR_CANDIDATE_AFFINITY_REVISED.md | DataTrust affinity scoring (revised) |
| TRIPLE_GRADING_ENHANCEMENT.md | Triple-grading donor scoring enhancement |

### 4F. Deployment & Technical Ops
| File | Purpose |
|------|---------|
| DEPLOYMENT_TECHNIQUES.md | Deployment methodology |
| NEXUS_DEPLOYMENT.md | Nexus brain deployment guide |
| NEXUS_README.md | Nexus brain README |
| RNC_DATAHUB_CONNECTION.md | RNC DataHub connection guide |
| DECEMBER_2024_README.md | December 2024 release notes |
| FILE_LOCATIONS.md | File locations reference |

### 4G. Cursor/Claude Session Handoff Documents
| File | Purpose |
|------|---------|
| CLAUDE-TO-CURSOR-GENERAL-NORM-FIX.md | Claude→Cursor normalization fix handoff |
| CLAUDE_10_QUESTIONS_RESPONSE_AND_CORRECTIVE_PLAN.md | Claude corrective plan |
| CLAUDE_BRIEFING_TO_CURSOR_donor_intelligence_2026-03-15.docx | Donor intelligence briefing for Cursor |
| CURSOR_BRIEFING_BOE_RELINK_2026-03-15.docx | BOE relink briefing for Cursor |
| CURSOR_BRIEFING_IDENTITY_RESOLUTION_V2_2026-03-15.docx | Identity resolution v2 briefing |
| Cursor-General-Fund-Ingestion-Instructions.docx | General fund ingestion instructions |
| Cursor-Identity-Resolution-Overhaul.docx | Identity resolution overhaul instructions |
| Cursor-Name-Pipeline-Fix-Instructions.docx | Name pipeline fix instructions |
| Report-to-Cursor-Database-Coordination.docx | Database coordination report |
| MIGRATION_071_CURSOR_INSTRUCTIONS_2026-03-15.docx | Migration 071 instructions |
| MIGRATION_071_EXECUTE_NOW_2026-03-16.docx | Migration 071 execution directive |
| COMET_REPAIR_GUIDE_JAN11_2026.md | Comet repair guide |

### 4H. Perplexity & Architecture Sessions
| File | Purpose |
|------|---------|
| Perplexity_Brain_Architecture_Session_Complete.md | Full Perplexity brain architecture session |
| perplexity-mar-6-5:30 pm-session.md | March 6 Perplexity session transcript |
| PERPLEXITY_SESSION_ALL_CODE_BLOCKS.py | All code blocks from Perplexity sessions |
| NC FIRST (BROYHILLGOP) 1A Platform Architecture March 12, 2026.md | NC FIRST platform architecture |
| B2B_ROCKET_ANALYSIS_BROYHILLGOP_REPLICATION.md | B2B Rocket replication analysis |
| NC BOE State Donor File Ingestion Pipeline.md | NC BOE ingestion pipeline spec |

### 4I. Heat Maps & Visual Reference
| File | Purpose |
|------|---------|
| docs/@GOD_FILE_INDEX_V4.html | GOD FILE INDEX v4 — master visual index |
| docs/code-heat-map-GOD.html | Code heat map — complete platform visualization |
| docs/The Complete 5-Layer Heat Map Schema.md | 5-layer heat map schema specification |
| docs/heat map nc council-fed.md | NC council-to-federal heat map |
| docs/nc supreme court cout appeals-code-heat-map.md | NC Supreme Court / Appeals heat map |
| docs/code-heatmap-education.md | Education policy code heat map |
| docs/ecoosystem-frontend-audit-directory-Gemini.md | Ecosystem frontend audit (Gemini) |

---

## SECTION 5: SESSION STATE FILES
**Location:** `/Users/Broyhill/Desktop/NCBOE-FEC- DONORS 2015-2026/`

| File | Purpose |
|------|---------|
| SESSION-STATE-Mar10.md | March 10, 2026 session state |
| SESSION-STATE-Mar11.md | March 11, 2026 session state |
| SESSION-STATE-Mar17.md | March 17, 2026 session state (includes FEC matching, 083-085 migrations) |

---

## SECTION 6: RAW DATA FILES
**Location:** `/Users/Broyhill/Desktop/NCBOE-FEC- DONORS 2015-2026/`

### FEC GOD Files (Federal Donation Data)
- 2015_FEC_GOD_FILE.csv through 2025_FEC_GOD_FILE_NC_REP.csv (11 files, 2015-2025)

### NC BOE Files (State/Local Donation Data)
- NCBOE-2015-2019.csv
- NCBOE-2020-2026-part1.csv, NCBOE-2020-2026-part2.csv
- 2015-2020-ncboe-general-funds.csv
- 2020-2026-ncboe-donors-general-fund.csv

### NCGOP / WinRed Financial Data
- NCGOP_WinRed_03:10:2026.csv / .numbers
- North_Carolina_Republican_PartyNCGOP_FinancialSearch_0362026_1400.xlsx
- 3-11-2026 NCGOP 2024-2026-071224_030526.xlsx

### County-Level Donor GOD Files
- Forsyth-DONORS-GOD-Contacts.csv / .xlsx
- Guilford-Donors-GOD_Contact.csv / .xlsx
- Mecklenburg-donor-GOD-Contact.csv / .xlsx
- NC-State-Top-100-DONORS-State-Local-2015-2026 (1).csv
- Mark-Robinson-2024.csv

### Committee Registries
- NCBOE_Committee_Registry.xlsx
- NC_BOE_Republican_Candidate_Committee_Directory.xlsx

### Legal / Formation Documents
- NC First, LLC Voter Database Diagram 4917-4281-7171 v.1.pdf

---

## SECTION 7: DATABASE STATE (As of Mar 17, 2026)

### Core Tables
| Table | Row Count | Description |
|-------|-----------|-------------|
| core.person_spine | 298,159 active | Master person records — the spine of the platform |
| public.fec_donations | ~2.6M | Federal donation records (2015-2025) |
| public.fec_party_committee_donations | ~1.7M | Party committee donation records |
| core.contribution_map | 3,109,705 | Unified donation map (FEC + Party + NC BOE) |
| public.datatrust_profiles | 7.6M | DataTrust voter/consumer data (NOT yet enriched onto spine) |

### Matching Results (Mar 17 Session)
- **FEC → Spine:** 2,247,173 of 2,597,935 linked (86.5%) via 3-tier matching
- **Party → Spine:** 1,264,467 of 1,734,568 linked (72.9%) via 2-tier matching
- **Contribution Map:** 3,109,705 rows (1,556,990 FEC + 1,264,467 party + 288,248 NC BOE)
- **Spine Aggregates Updated:** 174,503 spine records with recalculated totals ($217.7M linked)

### 3-Tier Matching Strategy
- **Tier 1** (confidence 0.95): Exact last name + zip5 + first name
- **Tier 2** (confidence 0.90): Canonical first name via name_variants + last + zip5
- **Tier 3** (confidence 0.85): Last name + zip5 + street number + first initial

---

## SECTION 8: KNOWN ISSUES & NEXT STEPS

### Priority 1: Fix Search Engine
`ecosystem_search_engine.py` currently only scans `.md` files. Must expand to: `.docx`, `.sql`, `.py`, `.xlsx`, `.numbers`, `.html`, `.json`

### Priority 2: GitHub Push Blocked
Prior commit contains secrets (Twilio, Stripe, Vercel, GitHub, Azure AD, Replicate tokens in MD Files/). Eddie has 8 unblock URLs to click.

### Priority 3: DataTrust Enrichment (BLOCKED — Needs Eddie's Approval)
All district, score, email, race fields are NULL on spine. 175,045 active spine records have voter_rncid but districts/scores/email never backfilled from datatrust_profiles.

### Priority 4: ED BROYHILL Matching Gap
46 of 48 ED BROYHILL FEC donations in zip 27104 unmatched — spine record at 27104 has `is_active = false`. Cross-zip merge candidate.

---

*This index covers 48 ecosystem reports, 51 SQL migrations, 134+ Python files, 85+ documentation files, and all raw data sources across the BroyhillGOP platform.*
