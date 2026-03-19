# Dedup & Identity Matching — Reference for Cursor

**Purpose:** Single source of truth for all match variables, strategies, and rules. Read this before modifying any dedup, voter-match, or identity-resolution logic.

---

## 1. NC Voter File = Authoritative Source

The NC voter file has **First, Middle, Last, Suffix** for every registered voter. This is legal, authoritative data.

- **nc_voters** columns: `first_name`, `middle_name`, `last_name`, `suffix` (or equivalent)
- **Never truncate** to first-initial-only when we have voter file access
- Use full name components in match keys: `last + first + middle + zip` (or `middle_initial` when full middle is sparse)

---

## 2. Match Variables (Use All Available)

| Variable | Source | Use In |
|----------|--------|--------|
| norm_last | donor/spine | All passes |
| norm_first | donor/spine | All passes |
| **norm_middle / middle_name** | donor, nc_voters, person_spine | **Include in match keys** |
| canonical_first | fn_normalize_donor_name | Nickname resolution (ED→EDGAR, ART→ARTHUR) |
| name_suffix | donor, nc_voters | Disambiguation (Jr, Sr, II, III) |
| norm_zip5 | donor | All passes |
| **street_number / po_box_number** | parsed from address | **High-significance marker** — same-address blocks |
| **address_block_key** | f(street_number, norm_last, zip5) | **Eddie's rule** — same-address donor block |
| voter_ncid | nc_voters | Definitive when present |
| employer_normalized | donor | Pass 5, Pass 6 blocking |
| address (normalized) | donor | Same-address blocks, cross-zip |
| email, phone | donor | Secondary signals |

**Critical:** Middle name matters. Example: "ED" is Edgar (middle name). Truncating to first-initial collapses "ED BROYHILL" with "EDWARD BROYHILL" — wrong. See MD FILES/feb 18-dedupe-name-variatrions.md.

**Critical:** Street number (or PO box number) is a **more significant** matching marker than street name. Address variations (casing, abbreviations, typos) affect street name; the number is stable. Use street_number + norm_last + zip5 for same-address blocks.

---

## 3. Variation Scale (From Your Data)

**Name variations:** Up to **20** per person (e.g. ED BROYHILL: ED, EDGAR, J EDGAR, JAMES ED, JAMES EDGAR BROYHILL, etc.).  
**Address variations:** Up to **15** per person (street name: casing, abbreviations, typos, zip formats).  
Street number is stable across address variations — use it as a primary match key.

**Address block key:** `street_number + norm_last + zip5` (Eddie's rule). When address is present, prefer this over name+zip alone.

---

## 4. Pass Order (From docs/INGESTION_PIPELINE_MASTER_PLAN.md)

- **Pass 1:** voter_ncid exact (definitive)
- **Pass 2:** email exact
- **Pass 3:** norm_last + norm_first + **norm_middle** + zip5 — **or address_block_key** (street_number + norm_last + zip5) when address present — **street_number is high-significance**
- **Pass 4:** norm_last + nickname_canonical + **norm_middle** + zip5 (core.nick_group)
- **Pass 5:** norm_last + first_initial + zip5 + employer — **only when middle unavailable**; prefer norm_middle when present
- **Pass 6:** Cross-zip multi-address — same person, different zips; requires shared ncid/email/phone/employer

**Do NOT use first-initial-only** as a primary strategy when nc_voters provides full name.

---

## 5. Existing Infrastructure (Do Not Recreate)

| Component | Location | Purpose |
|-----------|---------|---------|
| fn_normalize_donor_name | DB (Supabase) | canonical_first_name, last_name, first_name, suffix |
| pipeline.parse_ncboe_name | pipeline/nc_boe_ddl.sql | Returns norm_last, norm_first, middle_name, name_suffix — **use fn_normalize_donor_name for identity** |
| core.nick_group | core schema | Nickname→canonical (ED→EDGAR, ART→ARTHUR) |
| nc_boe_voter_match.py | pipeline/ | Matches nc_boe_donations_raw to nc_voters — **currently omits middle_name** |
| 068_PHASE2_VOTER_MATCHING.sql | database/migrations/ | Pass 1–3 — **Pass 3 uses first-initial; should use middle when available** |
| 066_PHASE1_SPINE_DEDUP.sql | database/migrations/ | Spine merge candidates — uses canonical_first, **not middle** |

---

## 6. Rules (From Weeks of Work)

1. **Never truncate** first/middle to initial when full name exists in nc_voters
2. **Include middle_name** (or middle_initial) in match keys
3. **Street number / PO box number** — more significant than street name; use for same-address blocks
4. **address_block_key** = street_number + norm_last + zip5 (Eddie's rule when address present)
5. **fn_normalize_donor_name** for identity resolution — NOT pipeline.parse_ncboe_name
6. **Address normalization** — up to 15 variations per person; street number is stable
7. **Name variation** — up to 20 per person; nickname resolution via core.nick_group / fn_normalize_donor_name
8. **Cross-zip** — Art Pope has 8–9 addresses; Pass 6 uses employer/email/phone as secondary signal
9. **Never delete** donations or spine records; mark is_active = false

---

## 7. Related Docs

- docs/INGESTION_PIPELINE_MASTER_PLAN.md — 6-pass identity resolution
- docs/RFC-001-ARCHITECTURE-REVIEW.md — norm_middle in schema
- docs/NCBOE_INGESTION_PIPELINE_MASTER_PLAN_V2.md — middle_name in raw
- docs/NC_VOTER_FILE_SCHEMA.md — nc_voters middle_name
- MD FILES/feb 18-dedupe-name-variatrions.md — ED Broyhill, Art Pope examples
- pipeline/nc_boe_dedup_fixes.sql — ED/EDGAR→edward backfill
