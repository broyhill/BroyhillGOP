# Session: Complete DataTrust Acxiom Supabase Setup
**Date:** March 21, 2026  
**Session ID:** local_8e41a1ff

---

## Database Status at End of Session

| Table | Rows | Status |
|-------|------|--------|
| nc_datatrust | 7.65M | 251 cols, crown jewel, DO NOT drop |
| datatrust_profiles | 7.65M | 69 cols, enriched ETL — DONE |
| nc_voters | 8.5M | NC voter registration |
| acxiom_consumer_data | 7.65M | loaded |
| fec_raw_schedule_a | 769K | 82 cols, raw FEC Schedule A |
| fec_schedule_a_raw | 585K | 79 cols, second FEC import |
| fec_contributions | 545K | 18 cols, cleaned |
| fec_donors | 394K | 14 cols, deduplicated |
| fec_donor_matches | 172K | FEC-to-donor_master links |
| donor_master | 545K | |
| ncsbe_candidates | 31K | all NC candidates |
| candidate_profiles | 9,759 | Republicans only |
| brain_rules | 46 | seeded |

## Critical Gaps (Blockers)
- **donor_contacts: 0 rows** — 5 views depend on it, HIGHEST PRIORITY
- fec_donor_master_links: 0 rows
- No fec_committees or fec_candidates reference tables
- committee_candidate_links: only 279 rows (incomplete)
- All campaign, AI, and brain_decisions tables empty

## Infrastructure
- **Supabase:** postgres / BroyhillGOP2026 @ db.isbgjpnbocdkeslofota.supabase.co:5432
- **Hetzner:** root @ 5.9.99.109 — SSH key: `~/.ssh/id_ed25519_hetzner`
- **Key dirs:** /opt/broyhillgop, /opt/political-crm, /opt/e49, /root/bulk_data
- **RunPod API:** rpa_ACAEJKYCMH2JST9HPQIK0IA6T4G3E0G2DMUXBTEW10a2x

## Technical Notes
- `safe_make_date()` function exists for bad DataTrust dates
- Bulk loading: ctid page-range batching (40K pages per batch) for massive unindexed tables
- Schema mismatches between DataTrust/FEC/NCBOE: different name formats, dates, party codes, no common ID key
- E20 Brain: BRAIN_HEARTBEAT.py + EVENT_CONSUMER.py on Hetzner
- Frontend: INSPINIA v4.0.1 Bootstrap 5, Vercel hosted

## Next Steps from This Session
1. Populate donor_contacts (unblocks 5 views)
2. Build fec_committees and fec_candidates reference tables
3. Finish committee_candidate_links (279 rows → complete)
