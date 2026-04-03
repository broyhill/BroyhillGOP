# RNC DataTrust Dimensional API — Deployment Plan
## Source: Danny Gustafson (dgustafson@gop.com), April 3, 2026
## Document: DimsDocumentationAPI.pdf — Winter 2026

---

## What Danny Sent

Three RNC API dimensional reference tables that provide lookup context
for the main voter file API and vote history fields.

---

## Table 1: DimElection
**Source:** SEIJI.DimElection
**Purpose:** Decode vote history column names and election types

| Column | Type | Description |
|--------|------|-------------|
| ElectionKey | smallint | Surrogate key |
| StateKey | smallint | Links to DimState |
| ElectionName | varchar(75) | Full election name |
| ElectionYear | smallint | Election cycle year |
| ElectionDate | date | Date of election event |
| ElectionType | char(2) | G=General, P=Primary, PP=Pres Primary, GP=Gen Primary, R=Runoff, S=Special, SY=Special Year, Y=Special General, M=Municipal, MP=Municipal Primary, PC=Pres Caucus |
| ElectionTypeName | varchar(20) | Human-readable type name |
| ElectionVHField | char(10) | The pivot field name in voter file (VH26G, VH24P, etc.) |
| RowCreateDatetime | datetime | Row created |
| RowUpdateDatetime | datetime | Row last updated |

## Table 2: DimOrganization
**Source:** gold.DimOrganization
**Purpose:** RNC integrated vendor organizations by state and cycle

| Column | Type | Description |
|--------|------|-------------|
| OrganizationKey | int | Surrogate key |
| OrganizationId | varchar(40) | Vendor-created org ID |
| VendorId | uniqueidentifier | UUID maps to DimVendor |
| State | char(2) | State abbreviation |
| FormalName | varchar(255) | Organization name |
| Cycle | varchar(50) | Cycle year |
| Active | smallint | 1=active, NULL=inactive |
| Classification | varchar(50) | DEPRECATED, will be NULL |
| RowCreateDateTime | datetime | |
| RowUpdateDateTime | datetime | |

## Table 3: DimTag
**Source:** gold.DimTag
**Purpose:** RNC initiative reporting tags — new tags generated each year

| Column | Type | Description |
|--------|------|-------------|
| TagKey | smallint | Surrogate key |
| TagName | varchar(50) | Tag name for reporting |
| TagShortName | varchar(50) | Short name |
| IsDeleted | bit | 1=no longer current |
| EnhancementTag | bit | DEPRECATED, will be NULL |
| RowCreateDatetime | datetime | |
| RowUpdateDatetime | datetime | |

---

## Why DimElection Is Critical

The vote history flags in staging.nc_voters_fresh (vh26g, vh24g, vh22g, etc.)
contain numeric codes that mean different things depending on the election system.

DimElection.ElectionVHField = the exact column name in the voter file.
This table decodes VH26G → "2026 General Election" → ElectionDate → ElectionType.

Without DimElection, vote history codes are unreadable integers.
With DimElection, every vh flag becomes a human-readable election event.

---

## Deployment Plan

### Phase 1 — Build the dim tables in Supabase (staging first)

```sql
-- DimElection
CREATE TABLE IF NOT EXISTS staging.dim_election (
  election_key SMALLINT PRIMARY KEY,
  state_key SMALLINT,
  election_name VARCHAR(75),
  election_year SMALLINT,
  election_date DATE,
  election_type CHAR(2),
  election_type_name VARCHAR(20),
  election_vh_field CHAR(10),
  row_create_datetime TIMESTAMPTZ,
  row_update_datetime TIMESTAMPTZ
);

-- DimOrganization
CREATE TABLE IF NOT EXISTS staging.dim_organization (
  organization_key INT PRIMARY KEY,
  organization_id VARCHAR(40),
  vendor_id UUID,
  state CHAR(2),
  formal_name VARCHAR(255),
  cycle VARCHAR(50),
  active SMALLINT,
  classification VARCHAR(50),
  row_create_datetime TIMESTAMPTZ,
  row_update_datetime TIMESTAMPTZ
);

-- DimTag
CREATE TABLE IF NOT EXISTS staging.dim_tag (
  tag_key SMALLINT PRIMARY KEY,
  tag_name VARCHAR(50),
  tag_short_name VARCHAR(50),
  is_deleted BIT,
  enhancement_tag BIT,
  row_create_datetime TIMESTAMPTZ,
  row_update_datetime TIMESTAMPTZ
);
```

### Phase 2 — Pull data from RNC API

Danny's API requires:
- IP whitelist for 144.76.219.24 (pending — emailed April 2)
- Existing whitelisted IP: 5.9.99.109 (can use this now)

API endpoint pattern (DataTrust standard):
```
GET /api/v1/dim/election?state=NC
GET /api/v1/dim/organization?state=NC
GET /api/v1/dim/tag
```

Until API is confirmed, request CSV exports from Danny.

### Phase 3 — Vote History Decoder View

Once DimElection is populated, build this view:

```sql
CREATE OR REPLACE VIEW public.v_vote_history_decoded AS
SELECT
  c.contact_id,
  c.last_name, c.first_name,
  de.election_name,
  de.election_date,
  de.election_type_name,
  CASE c.vh26g
    WHEN '1' THEN 'Voted In-Person'
    WHEN '2' THEN 'Voted Absentee'
    WHEN '7' THEN 'Voted Absentee/Mail'
    WHEN NULL THEN 'Did Not Vote'
    ELSE c.vh26g
  END AS vh26g_status
FROM public.contacts c
CROSS JOIN staging.dim_election de
WHERE de.election_vh_field = 'VH26G';
```

### Phase 4 — Move to public schema after validation

After staging validation:
- Move dim_election → public.dim_election
- Move dim_organization → public.dim_organization
- Move dim_tag → public.dim_tag
- Build indexes on election_vh_field and state_key

---

## Next Steps — Ask Danny

1. What is the API endpoint base URL for these dimensional tables?
2. Can he send CSV exports of DimElection for NC while the API whitelist is pending?
3. Are there additional dim tables? (DimState, DimVendor, DimPrecinct mentioned in docs)
4. What are the vote history code values? (1=in-person? 2=absentee? 7=mail?) Need the lookup.

---

## Files
- DimsDocumentationAPI.pdf — saved to docs/ in GitHub
- This deployment plan — sessions/DIMS_API_DEPLOYMENT_PLAN.md
