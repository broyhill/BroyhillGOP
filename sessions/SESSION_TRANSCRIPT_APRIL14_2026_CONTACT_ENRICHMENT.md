# Session Transcript — April 13-14, 2026
## Contact Enrichment Marathon: 17 Donor Files → 231K Cluster Spine

---

## Session Overview

**Date**: April 13-14, 2026 (evening through 1:37 AM EDT)
**Objective**: Load 17 external donor/contact files, match to NCBOE donation clusters, and stamp cell phones, home phones, personal emails, and business emails onto the spine (`raw.ncboe_donations`).
**Result**: Email coverage went from 0% → 19.1% (44,128 clusters). Phone coverage held steady at ~46% with incremental gains from new sources.

---

## Spine Baseline (Before Session)

| Metric | Value |
|---|---|
| Total transactions | 729,126 |
| Total clusters | 231,332 |
| Source files | 15 NCBOE gold CSVs + 2 supplemental (missing candidates, party committees) |
| Cell phone coverage | ~106K clusters (Neustar, Data Axle, voter file) |
| Home phone coverage | ~107K clusters (Neustar, Data Axle, voter file) |
| Email coverage | 0% — no emails existed |

---

## Matching Infrastructure Built

- **staging.ncboe_cluster_reps** (158,461 rows): One representative per cluster with `norm_last`, `norm_first`, `norm_zip5`, `cluster_id`. Indexed on `(norm_last, norm_zip5)`.
- **staging.cluster_dominant_name** (230,533 rows): Dominant name per cluster weighted by total donation dollars.
- **Matching logic**: `norm_last = p_last AND LEFT(norm_first, 3) = LEFT(p_first, 3) AND norm_zip5 = zip5`
- **Email classification**: Long list of personal domains (gmail, yahoo, hotmail, aol, icloud, etc.) → `personal_email`; everything else → `business_email`
- **Phone cleaning**: `REGEXP_REPLACE(phone, '[^0-9]', '', 'g')`, truncate to 10 digits
- **Stamping rule**: Only write where field `IS NULL` — never overwrite existing data

---

## Files Loaded (Chronological Order)

### 1. WinRed / NCGOP Combined (248K → 58K deduped)
- **Sources**: `North_Carolina_Republican_PartyNCGOP_Financial-donors.csv` (194K) + `North_Carolina_Republican_PartyNCGOP_FinancialSearch_0362026_1400.csv` (54K)
- **Combined**: 248,341 rows → 58,449 unique contacts after dedup
- **Matched**: 17,882 rows to 16,473 clusters
- **Stamped**: 7,846 personal emails / 1,568 business emails / 208 cell phones / 1,824 home phones
- **Note**: First file recognized as same party committee data Ed already had; second was the updated 2026 extract

### 2. Harris Congressman Donors (72 rows)
- **File**: `harris-congressman.csv`
- **Matched**: 55 to clusters
- **Stamped**: Cell phones + spouse contact info (7 cluster contacts, 5 spouse contacts)
- **Special**: Had spouse names and cell phones — linked as household contacts

### 3. Budd Senate Donors (1,442 rows)
- **File**: `budd.csv`
- **Matched**: 1,194 to clusters
- **Stamped**: 109 personal / 107 business emails, 23 cell / 20 home phones
- **Format**: DataFinder export with home/work/mobile/other phone + personal/home/work/other email

### 4. Budd Forsyth (994 rows)
- **File**: `budd-forsyth.csv`
- **Matched**: 880 to clusters
- **Stamped**: 85 personal / 55 business emails, 6 cell / 28 home phones

### 5. Budd Guilford (963 rows)
- **File**: `budd-guilford.csv`
- **Matched**: 812 to clusters
- **Stamped**: 93 personal / 54 business emails, 12 cell / 28 home phones

### 6. Budd Wake (1,715 rows)
- **File**: `budd-wake.csv`
- **Matched**: 1,416 to clusters
- **Stamped**: 134 personal / 117 business emails, 31 cell / 34 home phones

### 7. Trump NC Full (421 rows)
- **File**: `TrumpDonorsNC-full.csv`
- **Matched**: 365 to clusters
- **Stamped**: 12 personal / 56 business emails, 1 cell / 2 home phones

### 8. NCGOP Forsyth (710 rows)
- **File**: `NCGOP-DONORS-FORSYTH.csv`
- **Matched**: 626 to clusters (after dedup to 288)
- **Stamped**: Phones and emails (incremental, most already covered)

### 9. Apollo — THE GAME CHANGER (112,497 rows)
- **File**: `BroyhillGOP_Full_Apollo_Updated.csv`
- **Deduped**: 109,906 unique contacts
- **Matched**: 50,678 to clusters
- **Stamped**: 29,179 personal emails / 4,107 business emails / 7,801 cell phones / 7,033 home phones
- **Impact**: Single largest source of email data. Took email coverage from ~10K to ~40K clusters.
- **BUG FOUND**: Apollo had `jsneeden@msn.com` mapped to James Broyhill at ZIP 27104 — this incorrectly stamped Ed's cluster 372171 with a stranger's email as personal_email. **Fixed**: Cleared the bad email. Later discovered Master Unified propagated the same bad data — cleared again.

### 10. Master Unified (220,878 rows)
- **File**: `NC_MASTER_Unified_Donors.csv`
- **Deduped**: 198,088 unique contacts
- **Matched**: 92,795 to clusters
- **Stamped**: 1,310 personal / 228 business emails, 41 cell / 237 home phones (incremental over Apollo)
- **BUG**: Propagated same `jsneeden@msn.com` bad email from Apollo — cleared from Ed's cluster a second time

### 11. Military NC (16,355 rows)
- **File**: `NC_Military_Donors_Tagged.csv`
- **Deduped**: 16,027 unique contacts
- **Matched**: 9,594 to clusters
- **Stamped**: 172 personal / 596 business emails, 57 cell / 77 home phones
- **Note**: High ratio of business emails (military .mil addresses classified as business)

### 12. Trump Rally Donors (9,999 rows)
- **File**: `trump-Rally-Donors.csv`
- **Deduped**: 7,454 unique contacts
- **Matched**: 4,082 to clusters
- **Stamped**: `trump_rally_donor = TRUE` on 4,082 clusters (1.8% of all clusters)
- **No contact info**: File only had names/addresses — used purely for tagging
- **Ed's instruction**: "tag these people as die hard trump rally attendees"

### 13. NCGOP 2026 (24,680 rows)
- **File**: `North_Carolina_Republican_PartyNCGOP_FinancialSearch_0362026_1400.csv`
- **Deduped**: 10,611 unique contacts
- **Matched**: 3,662 to clusters
- **Stamped**: 307 personal / 73 business emails, 1 cell / 58 home phones

### 14. Foxx (193 rows)
- **File**: `foxx.csv`
- **Matched**: ~66 to clusters
- **Stamped**: 4 home phones (small file, most already covered)

### 15. Trump Lake Norman Fundraiser (63 rows)
- **File**: `trump-fundraiser-lake-norma.csv`
- **Matched**: 24 to clusters
- **Stamped**: 4 personal / 4 business emails

### 16. Jim O'Neill 2016 Finance Donors (501 rows)
- **File**: `JIMONEILL-2016FinanceDonors_datafinder_20180924.csv`
- **Matched**: 473 to clusters (94.4%)
- **Stamped**: 10 cell phones (Mobile type) / 18 home phones (Unknown Type/VOIP)
- **No emails**: File had phones only
- **Issues fixed**:
  - CR-only line endings (old Mac format) → converted to LF
  - "File Inputs" meta-header on row 1 → stripped, used row 2 as actual header
  - Quoted commas in employer names → pipe-delimited intermediate file for clean COPY
  - Suffix-as-last-name (JR/SR in last_name field) → used middle_name as real last name
  - Apostrophe matching (O'NEILL vs ONEILL) → stripped apostrophes both sides

---

## Critical Bug: Apollo Bad Email on Ed's Cluster

**What happened**: Apollo file had a record for "JAMES BROYHILL" at ZIP 27104 with email `jsneeden@msn.com`. This matched to cluster 372171 (Ed's cluster, which includes his father James Broyhill's donations per Ed's instructions). The email was stamped as `personal_email` because msn.com is a personal domain.

**Impact**: Ed's cluster showed a stranger's email as his personal email.

**Fix**: Cleared `personal_email` and `personal_email_source` on cluster 372171. Had to do it twice because Master Unified (which was derived from Apollo data) re-stamped the same bad email.

**Prevention**: The IS NULL guard prevents overwrites, so once cleared, no other source can re-stamp unless the field is empty when the UPDATE runs. Both Apollo and Master Unified ran in the same session before the bug was caught.

---

## Final Contact Coverage (231,332 clusters)

| Contact Type | Clusters | % of Total |
|---|---|---|
| Cell phone | 106,961 | 46.2% |
| Home phone | 107,086 | 46.3% |
| Personal email | 39,250 | 17.0% |
| Business email | 6,965 | 3.0% |
| Any email | 44,128 | 19.1% |
| Trump rally tagged | 4,082 | 1.8% |

### Email Sources (by cluster count)
| Source | Personal | Business |
|---|---|---|
| apollo | 29,179 | 4,107 |
| ncgop_winred | 7,846 | 1,568 |
| master_unified | 1,310 | 228 |
| military_nc | 172 | 596 |
| ncgop_2026 | 307 | 73 |
| budd_wake | 134 | 117 |
| budd_senate | 109 | 107 |
| budd_guilford | 93 | 54 |
| budd_forsyth | 85 | 55 |
| trump_nc | 12 | 56 |
| trump_lake_norman | 4 | 4 |

### Phone Sources (top, by cluster count)
| Source | Cell | Home |
|---|---|---|
| neustar,data_axle | 39,855 | 39,081 |
| data_axle | 23,670 | 31,100 |
| neustar | 13,418 | 11,290 |
| voter_file,neustar,data_axle | 12,149 | 12,789 |
| apollo | 7,801 | 7,033 |
| voter_file,neustar | 7,387 | 3,097 |
| ncgop_winred | 208 | 1,824 |
| voter_file | 2,604 | 420 |
| voter_file,data_axle | 890 | 974 |
| master_unified | 41 | 237 |
| military_nc | 57 | 77 |

---

## Ed's Cluster 372171 — Verified Clean

| Field | Value | Source |
|---|---|---|
| cell_phone | 3369721000 | neustar,data_axle |
| cell_phone_reliability | H | — |
| home_phone | 3367243726 | neustar,data_axle |
| business_email | ed@broyhill.net | ncgop_winred |
| personal_email | NULL | cleared (Apollo bad data) |
| trump_rally_donor | — | not tagged |
| Cluster txns | 187 | — |
| Cluster total | $488,577 | — |

---

## Staging Tables on Hetzner (50 tables)

All intermediate staging tables preserved in `staging.*` schema for audit trail. Key infrastructure tables:
- `staging.ncboe_cluster_reps` — 158,461 cluster representative records (matching backbone)
- `staging.cluster_dominant_name` — 230,533 dominant names by donation dollars

---

## Architecture Decisions

1. **Contact enrichment only** — donor files used for phones/emails, NOT for adding donation amounts to spine (Ed confirmed: "dont add donations. thats old")
2. **IS NULL guard** — never overwrite existing contact data; first source wins
3. **Source provenance** — every stamped field has a `_source` column tracking which file provided it
4. **Email classification** — personal vs business determined by domain (gmail/yahoo/hotmail/etc = personal, all else = business)
5. **Phone type mapping** — Mobile → cell_phone, Unknown Type/VOIP → home_phone, reliability M for match-confirmed, L for VOIP
6. **Name matching** — LEFT(norm_first, 3) for fuzzy first name matching, exact on last name + ZIP5
7. **ED = EDGAR** — hardcoded name parser rule per Ed's standing instruction

---

## What's NOT Done / Next Steps

- **Donation dollar amounts from external files NOT added to spine** — Ed confirmed these are old and should not be appended
- **Partition #7 and #8** (July 31 deadline) — not addressed this session
- **Stage 2 voter matching** — `ncboe_stage2_voter_match.py` exists but not run this session
- **Brain worker** — Engineering deliverable, not our job
- **Additional contact sources** — coverage ceiling without new data sources: 46% phone, 19% email
