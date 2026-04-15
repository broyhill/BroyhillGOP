# SESSION_STATE — BroyhillGOP Database
Last verified: 2026-04-15 ~03:30 UTC | Updated by: Perplexity-April15

## VERIFIED ROW COUNTS
| Table | Rows | Status |
|-------|------|--------|
| raw.ncboe_donations | 2,431,198 | CORRECT — 18 GOLD files |
| staging.ncboe_party_committee_donations | 518,077 | Separate table |
| core.datatrust_voter_nc | 7,727,637 | INTACT |
| core.acxiom_* (4 tables) | 7,655,593 each | INTACT |

## NEW THIS SESSION (April 15) — Committee Infrastructure Tables

### 10 committee tables replicated from Supabase to Hetzner
Method: REST API (public tables) + RPC functions (core/staging tables)
All row counts verified against Supabase source.

**committee schema (NEW — 5 tables from Supabase public.**):**
| Table | Rows | Source |
|-------|------|--------|
| committee.registry | 10,975 | public.committee_registry |
| committee.office_type_map | 1,550 | public.committee_office_type_map |
| committee.boe_candidate_map | 648 | public.boe_committee_candidate_map |
| committee.party_map | 19,982 | public.committee_party_map |
| committee.ncsbe_candidate_master | 4,165 | public.ncsbe_candidate_committee_master |

**core schema (3 new tables):**
| Table | Rows | Source |
|-------|------|--------|
| core.ncboe_committee_registry | 2,032 | core.ncboe_committee_registry |
| core.ncboe_committee_type_lookup | 2,039 | core.ncboe_committee_type_lookup |
| core.candidate_committee_map | 5,761 | core.candidate_committee_map |

**staging schema (2 new tables):**
| Table | Rows | Source |
|-------|------|--------|
| staging.sboe_committee_master | 13,237 | staging.sboe_committee_master |
| staging.committee_candidate_bridge | 864 | staging.committee_candidate_bridge |

## CONTACT ENRICHMENT STATUS — ALL STEPS COMPLETE (unchanged)
| Field | Rows | Clusters | Status |
|-------|------|----------|--------|
| cell_phone | 1,473,906 | 70,342+ | DONE |
| home_phone | 1,483,928 | 71,348 | DONE |
| personal_email | 984,285 | 35,422 | DONE |
| business_email | 342,489 | 6,993 | DONE |
| trump_rally_donor | 447,537 | 3,860 | DONE |
| zip9 | 1,263,092 | — | DONE |

## GOLD STANDARD — ED CLUSTER 372171
txns=627 | total=$1,318,672.04 | cell=3369721000 | home=3367243726
p_email=ed@broyhill.net | b_email=jim@broyhill.net | rally=TRUE | zip9=271043224
Party committee giving: $155,945.45 across 17 orgs

## NEXT STEPS
- Join committee tables to spine + party committee donations (Step 5)
- Build candidate↔committee_sboe_id bridge (fuzzy match per sessions/2026-03-31 SQL)
- RNC API pulls: FactInitiativeContacts + Absentee (tested, staging tables ready)
- Match remaining 153K party-only donors to DataTrust voter file
- Lock down PostgreSQL port 5432

