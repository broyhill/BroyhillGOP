# BROYHILLGOP TRIPLE GRADING ENHANCEMENT
## December 2024

---

## OVERVIEW

Upgrade from **Dual Grading** (State/County) to **Triple Grading** (State/District/County) with automatic context selection based on candidate's office type.

---

## FILES CREATED

### 1. Database Schema
**File:** `/database/schemas/CALCULATE_TRIPLE_GRADES.sql`

**New Columns Added to `persons` table:**
- `district_state_house` VARCHAR(10) - e.g., "HD-087"
- `district_state_senate` VARCHAR(10) - e.g., "SD-41"
- `district_us_house` VARCHAR(10) - e.g., "CD-05"
- `district_judicial` VARCHAR(20)
- `donor_grade_district` VARCHAR(3)
- `donor_rank_district` INTEGER
- `donor_percentile_district` DECIMAL(6,3)

**New Table:**
- `nc_districts` - Lookup table with 120 House, 50 Senate, 14 Congressional districts

---

### 2. Frontend UI
**File:** `/frontend/candidate-portal/ecosystem-donor-intelligence-triple.html`

**Features:**
- Three-way toggle: Statewide | By District | By County
- District dropdown selector (House, Senate, Congressional)
- County dropdown selector (100 NC counties)
- Triple grade comparison view (side-by-side)
- Active column highlighting based on selection
- Grade badge highlighting in table
- Office Context Mapping reference table

---

### 3. Python Module
**File:** `/backend/python/ecosystems/nc_office_context_mapping.py`

**Functions:**
- `get_grade_context(office_type)` - Returns STATE/DISTRICT/COUNTY
- `get_contextual_grade(donor, office_type)` - Returns appropriate grade/rank
- `get_donation_level_for_grade(grade)` - Maps grade to standard menu
- `get_donation_level_for_donor(donor, office_type)` - Main function for Campaign Builder
- `calculate_realistic_capacity(donors_by_grade, office_type)` - Pre-campaign reality check
- `calculate_expanded_capacity(base_capacity, guest_type)` - Special guest multiplier

---

## OFFICE CONTEXT MAPPING

| Office Type | Grade Context | Reason |
|-------------|---------------|--------|
| **US Senate** | State | Statewide electorate |
| **US House** | District | Congressional district |
| **Governor, Lt. Gov** | State | Statewide offices |
| **Council of State (10)** | State | Statewide offices |
| **NC Supreme Court** | State | Statewide judicial |
| **NC Court of Appeals** | State | Statewide judicial |
| **NC State Senate** | District | Senate districts |
| **NC State House** | District | House districts |
| **Superior Court** | District | Judicial districts |
| **District Court** | District | Judicial districts |
| **County Commissioner** | County | County-wide |
| **Sheriff** | County | County-wide |
| **Register of Deeds** | County | County-wide |
| **Clerk of Court** | County | County-wide |
| **Mayor** | County | Municipal |
| **City Council** | County | Municipal |
| **School Board** | County | Local board |

---

## GRADE TO DONATION MENU MAPPING

| Grade | Donation Ask | Percentile |
|-------|-------------|------------|
| A++ | $6,800 | Top 0.1% |
| A+ | $5,000 | Top 1% |
| A | $2,500 | Top 5% |
| A- | $1,000 | Top 10% |
| B+ | $1,000 | Top 20% |
| B | $500 | Top 30% |
| B- | $500 | Top 40% |
| C+ | $500 | Top 50% |
| C | $100 | Top 60% |
| C- | $100 | Top 70% |
| D+ | $100 | Top 80% |
| D | $100 | Top 90% |
| D- | $100 | Bottom 10% |
| U | $100 | Unknown but qualified |

---

## SPECIAL GUEST MULTIPLIERS

| Guest Type | Multiplier | Example Capacity |
|------------|------------|------------------|
| US Senator | 4.0x | $45K → $180K |
| Governor | 3.5x | $45K → $157K |
| US Congressman | 2.5x | $45K → $112K |
| State Speaker | 2.0x | $45K → $90K |
| Lt. Governor | 2.0x | $45K → $90K |
| Celebrity | 2.0x | $45K → $90K |
| State Senate Leader | 1.5x | $45K → $67K |
| State Senator | 1.3x | $45K → $58K |

---

## EXAMPLE: SAME DONOR, THREE GRADES

**Sarah Mitchell** - Caldwell County, HD-87

| Context | Grade | Rank | Recommended Ask |
|---------|-------|------|-----------------|
| Statewide | B+ | #8,234 of 243,575 | $1,000 |
| HD-87 District | A+ | #2 of 2,847 | $5,000 |
| Caldwell County | A++ | #1 of 1,845 | $6,800 |

**For Destin Hall (State House):** Use District grade → Ask $5,000
**For Governor Race:** Use State grade → Ask $1,000

---

## INTEGRATION POINTS

### Campaign Wizard (E41)
```python
from nc_office_context_mapping import get_donation_level_for_donor

# When sorting donors for event
for donor in donors:
    ask_level = get_donation_level_for_donor(donor, candidate.office_type)
    assign_to_reply_card_level(donor, ask_level)
```

### Events (E34)
```python
from nc_office_context_mapping import calculate_realistic_capacity

# Pre-campaign reality check
capacity = calculate_realistic_capacity(donors_by_grade, "state_house")
if campaign.goal > capacity['realistic_max']:
    suggest_special_guest_or_multi_event()
```

### Donor Intelligence (E01)
```python
from nc_office_context_mapping import get_contextual_grade

# Display appropriate grade in UI
grade, rank = get_contextual_grade(donor, candidate.office_type)
```

---

## DEPLOYMENT STEPS

1. **Run SQL Migration:**
   ```bash
   psql -d broyhillgop -f CALCULATE_TRIPLE_GRADES.sql
   ```

2. **Populate District Assignments:**
   - Import voter file with district assignments
   - Match donors to districts by address

3. **Deploy UI:**
   - Replace `ecosystem-donor-intelligence-dual.html` with `ecosystem-donor-intelligence-triple.html`

4. **Update Campaign Builder:**
   - Import `nc_office_context_mapping` module
   - Use `get_donation_level_for_donor()` in audience sorting

---

## KNOWN LIMITATION: SUB-COUNTY RACES

**Current system uses COUNTY as smallest context, but many local races are PARTIAL county:**

| Race Type | Reality | Workaround |
|-----------|---------|------------|
| School Board | School district boundaries | County grade (imprecise) |
| City Council | City limits / Wards | County grade (imprecise) |
| County Commissioner | Often districted | County grade (imprecise) |
| Mayor | City limits only | County grade (imprecise) |

**Future:** Add municipal/school district boundary data when available.

---

## FUTURE ENHANCEMENTS

1. **Municipal-Level Grading** - When boundary data available
2. **Historical Grade Trends** - Track grade changes over time
3. **Grade Prediction** - ML to predict grade based on engagement
