# NC DataTrust Migration Plan
## staging.nc_voters_fresh → public.nc_datatrust

**Prepared:** April 2, 2026
**Source file:** NC_VoterFile_FULL_20260312_035808.csv (March 12, 2026 build)
**Source token:** Received from Danny Gustafson (dgustafson@gop.com), expires April 10, 2026
**Token status:** File currently downloading to Hetzner (/opt/broyhillgop/data/voter_file/)
**Staging table:** staging.nc_voters_fresh (251 cols, ~9M rows)
**Target table:** public.nc_datatrust (256 cols = 251 DataTrust + 5 norm_ cols we added)
**Primary join key:** rncid (column 1)
**Secondary join key:** statevoterid (column 54)

---

## ⚠️ GUARDRAILS (Per Perplexity MSG #221 — April 2, 2026)

**SACRED TABLE — nc_datatrust may NOT be touched without explicit Ed authorization.**
Exact phrase required to proceed: `I authorize this action`

**Claude MAY:**
- SELECT from anywhere
- CREATE TEMP TABLEs
- CREATE in staging schema only (prefix: `staging_claude_`)
- COMMIT documents and SQL scripts to GitHub

**Claude MAY NOT:**
- DROP/ALTER nc_datatrust or any core/public/archive/norm/raw/staging/audit schema tables
- UPDATE/DELETE from nc_datatrust, nc_boe_donations_raw, core.person_spine, public.contacts
- Execute any of the SQL in this document without explicit authorization

**Two-Phase Protocol:** DRY RUN first → Ed says "I authorize this action" → EXECUTION

**Ed = ED BROYHILL** in all systems. Never map to Edward.

**⚠️ DO NOT EXECUTE — Perplexity reviews before any production changes.**

---

## Section 1: Schema Comparison Summary

| Category | Count | Notes |
|----------|-------|-------|
| Exact column matches (name + position) | 247 | Direct UPDATE mapping |
| Renamed columns (fresh → datatrust) | 4 | See Section 2 |
| Columns only in nc_datatrust (our additions) | 5 | PRESERVE — do not touch |
| Brand-new columns in fresh not in datatrust | 0 | No new DataTrust columns this cycle |

---

## Section 2: The 4 Renamed Columns

DataTrust corrected a naming inconsistency — the upper legislative district fields now use `statelegs` (matching the lower district naming pattern) instead of `stateleg`.

| Position | nc_datatrust (OLD name) | nc_voters_fresh (NEW name) | Action |
|----------|-------------------------|---------------------------|--------|
| 28 | `statelegupperdistrict` | `statelegsupperdistrict` | RENAME col in nc_datatrust |
| 29 | `statelegupperdistrict_previouselection` | `statelegsupperdistrict_previouselection` | RENAME col in nc_datatrust |
| 30 | `statelegupperdistrict_proper` | `statelegsupperdistrict_proper` | RENAME col in nc_datatrust |
| 31 | `statelegupperdistrict_proper_previouselection` | `statelegsupperdistrict_proper_previouselection` | RENAME col in nc_datatrust |

**Why rename rather than map?** Keeping the old names creates confusion downstream — ecosystem queries and any app code referencing these columns should use the canonical DataTrust name going forward.

---

## Section 3: Columns Preserved (Our Additions — DO NOT OVERWRITE)

These 5 columns were added by BroyhillGOP and do not exist in the DataTrust file. They must not be touched by the UPDATE.

| Position | Column | Purpose |
|----------|--------|---------|
| 252 | `norm_first` | Normalized first name for identity matching |
| 253 | `norm_last` | Normalized last name for identity matching |
| 254 | `norm_zip5` | Normalized ZIP for identity matching |
| 255 | `addr_type` | Address type classification |
| 256 | `norm_street_num` | Normalized street number |

---

## Section 4: Full 251-Column Mapping

All 247 exact matches, 4 renames shown with arrows.

| Pos | nc_voters_fresh column | nc_datatrust column | Status |
|-----|------------------------|---------------------|--------|
| 1 | rncid | rncid | ✅ MATCH |
| 2 | rnc_regid | rnc_regid | ✅ MATCH |
| 3 | prev_rncid | prev_rncid | ✅ MATCH |
| 4 | state | state | ✅ MATCH |
| 5 | statekey | statekey | ✅ MATCH |
| 6 | ispartyreg | ispartyreg | ✅ MATCH |
| 7 | sourceid | sourceid | ✅ MATCH |
| 8 | juriscode | juriscode | ✅ MATCH |
| 9 | jurisname | jurisname | ✅ MATCH |
| 10 | countyfips | countyfips | ✅ MATCH |
| 11 | countyname | countyname | ✅ MATCH |
| 12 | mediamarket | mediamarket | ✅ MATCH |
| 13 | censusblock2020 | censusblock2020 | ✅ MATCH |
| 14 | metrotype | metrotype | ✅ MATCH |
| 15 | mcd | mcd | ✅ MATCH |
| 16 | statecountycode | statecountycode | ✅ MATCH |
| 17 | statetowncode | statetowncode | ✅ MATCH |
| 18 | ward | ward | ✅ MATCH |
| 19 | precinctcode | precinctcode | ✅ MATCH |
| 20 | precinctname | precinctname | ✅ MATCH |
| 21 | ballotbox | ballotbox | ✅ MATCH |
| 22 | schoolboard | schoolboard | ✅ MATCH |
| 23 | schooldistrict | schooldistrict | ✅ MATCH |
| 24 | citycouncil | citycouncil | ✅ MATCH |
| 25 | countycommissioner | countycommissioner | ✅ MATCH |
| 26 | congressionaldistrict | congressionaldistrict | ✅ MATCH |
| 27 | congressionaldistrict_previouselection | congressionaldistrict_previouselection | ✅ MATCH |
| 28 | statelegsupperdistrict | statelegupperdistrict → **statelegsupperdistrict** | 🔄 RENAME |
| 29 | statelegsupperdistrict_previouselection | statelegupperdistrict_previouselection → **statelegsupperdistrict_previouselection** | 🔄 RENAME |
| 30 | statelegsupperdistrict_proper | statelegupperdistrict_proper → **statelegsupperdistrict_proper** | 🔄 RENAME |
| 31 | statelegsupperdistrict_proper_previouselection | statelegupperdistrict_proper_previouselection → **statelegsupperdistrict_proper_previouselection** | 🔄 RENAME |
| 32 | stateleglowerdistrict | stateleglowerdistrict | ✅ MATCH |
| 33 | stateleglowerdistrict_previouselection | stateleglowerdistrict_previouselection | ✅ MATCH |
| 34 | stateleglowersubdistrict | stateleglowersubdistrict | ✅ MATCH |
| 35 | stateleglowersubdistrict_previouselection | stateleglowersubdistrict_previouselection | ✅ MATCH |
| 36 | stateleglowerdistrict_proper | stateleglowerdistrict_proper | ✅ MATCH |
| 37 | stateleglowerdistrict_proper_previouselection | stateleglowerdistrict_proper_previouselection | ✅ MATCH |
| 38 | nameprefix | nameprefix | ✅ MATCH |
| 39 | firstname | firstname | ✅ MATCH |
| 40 | middlename | middlename | ✅ MATCH |
| 41 | lastname | lastname | ✅ MATCH |
| 42 | namesuffix | namesuffix | ✅ MATCH |
| 43 | sex | sex | ✅ MATCH |
| 44 | birthyear | birthyear | ✅ MATCH |
| 45 | birthmonth | birthmonth | ✅ MATCH |
| 46 | birthday | birthday | ✅ MATCH |
| 47 | age | age | ✅ MATCH |
| 48 | agerange | agerange | ✅ MATCH |
| 49 | congressionalagerange | congressionalagerange | ✅ MATCH |
| 50 | registeredparty | registeredparty | ✅ MATCH |
| 51 | partyrollup | partyrollup | ✅ MATCH |
| 52 | calcparty | calcparty | ✅ MATCH |
| 53 | modeledparty | modeledparty | ✅ MATCH |
| 54 | statevoterid | statevoterid | ✅ MATCH |
| 55 | jurisdictionvoterid | jurisdictionvoterid | ✅ MATCH |
| 56 | lastactivitydate | lastactivitydate | ✅ MATCH |
| 57 | registrationdate | registrationdate | ✅ MATCH |
| 58 | registrationdatesource | registrationdatesource | ✅ MATCH |
| 59 | voterstatus | voterstatus | ✅ MATCH |
| 60 | permanentabsentee | permanentabsentee | ✅ MATCH |
| 61 | ethnicityreported | ethnicityreported | ✅ MATCH |
| 62 | ethnicitymodeled | ethnicitymodeled | ✅ MATCH |
| 63 | ethnicgroupmodeled | ethnicgroupmodeled | ✅ MATCH |
| 64 | ethnicgroupnamemodeled | ethnicgroupnamemodeled | ✅ MATCH |
| 65 | religionmodeled | religionmodeled | ✅ MATCH |
| 66 | languagemodeled | languagemodeled | ✅ MATCH |
| 67 | acsethnicity_white | acsethnicity_white | ✅ MATCH |
| 68 | acsethnicity_black | acsethnicity_black | ✅ MATCH |
| 69 | acsethnicity_hispanic | acsethnicity_hispanic | ✅ MATCH |
| 70 | acsethnicity_asian | acsethnicity_asian | ✅ MATCH |
| 71 | acsethnicity_other | acsethnicity_other | ✅ MATCH |
| 72 | acseducation_highschool | acseducation_highschool | ✅ MATCH |
| 73 | acseducation_college | acseducation_college | ✅ MATCH |
| 74 | acseducation_graduate | acseducation_graduate | ✅ MATCH |
| 75 | acseducation_vocational | acseducation_vocational | ✅ MATCH |
| 76 | acseducation_none | acseducation_none | ✅ MATCH |
| 77 | householdid | householdid | ✅ MATCH |
| 78 | householdmemberid | householdmemberid | ✅ MATCH |
| 79 | householdparty | householdparty | ✅ MATCH |
| 80 | registrationaddr1 | registrationaddr1 | ✅ MATCH |
| 81 | registrationaddr2 | registrationaddr2 | ✅ MATCH |
| 82 | reghousenum | reghousenum | ✅ MATCH |
| 83 | reghousesfx | reghousesfx | ✅ MATCH |
| 84 | regstprefix | regstprefix | ✅ MATCH |
| 85 | regstname | regstname | ✅ MATCH |
| 86 | regsttype | regsttype | ✅ MATCH |
| 87 | regstpost | regstpost | ✅ MATCH |
| 88 | regunittype | regunittype | ✅ MATCH |
| 89 | regunitnumber | regunitnumber | ✅ MATCH |
| 90 | regcity | regcity | ✅ MATCH |
| 91 | regsta | regsta | ✅ MATCH |
| 92 | regzip5 | regzip5 | ✅ MATCH |
| 93 | regzip4 | regzip4 | ✅ MATCH |
| 94 | reglatitude | reglatitude | ✅ MATCH |
| 95 | reglongitude | reglongitude | ✅ MATCH |
| 96 | reggeocodelevel | reggeocodelevel | ✅ MATCH |
| 97 | reglastcleanse | reglastcleanse | ✅ MATCH |
| 98 | reglastgeocode | reglastgeocode | ✅ MATCH |
| 99 | reglastcoa | reglastcoa | ✅ MATCH |
| 100 | changeofaddresssource | changeofaddresssource | ✅ MATCH |
| 101 | changeofaddressdate | changeofaddressdate | ✅ MATCH |
| 102 | changeofaddresstype | changeofaddresstype | ✅ MATCH |
| 103 | mailingaddr1 | mailingaddr1 | ✅ MATCH |
| 104 | mailingaddr2 | mailingaddr2 | ✅ MATCH |
| 105 | mailhousenum | mailhousenum | ✅ MATCH |
| 106 | mailhousesfx | mailhousesfx | ✅ MATCH |
| 107 | mailstprefix | mailstprefix | ✅ MATCH |
| 108 | mailstname | mailstname | ✅ MATCH |
| 109 | mailsttype | mailsttype | ✅ MATCH |
| 110 | mailstpost | mailstpost | ✅ MATCH |
| 111 | mailunittype | mailunittype | ✅ MATCH |
| 112 | mailunitnumber | mailunitnumber | ✅ MATCH |
| 113 | mailcity | mailcity | ✅ MATCH |
| 114 | mailsta | mailsta | ✅ MATCH |
| 115 | mailzip5 | mailzip5 | ✅ MATCH |
| 116 | mailzip4 | mailzip4 | ✅ MATCH |
| 117 | mailsortcoderoute | mailsortcoderoute | ✅ MATCH |
| 118 | maildeliverypt | maildeliverypt | ✅ MATCH |
| 119 | maildeliveryptchkdigit | maildeliveryptchkdigit | ✅ MATCH |
| 120 | maillineoftravel | maillineoftravel | ✅ MATCH |
| 121 | maillineoftravelorder | maillineoftravelorder | ✅ MATCH |
| 122 | maildpvstatus | maildpvstatus | ✅ MATCH |
| 123 | maillastcleanse | maillastcleanse | ✅ MATCH |
| 124 | maillastcoa | maillastcoa | ✅ MATCH |
| 125 | cell | cell | ✅ MATCH |
| 126 | cellsourcecode | cellsourcecode | ✅ MATCH |
| 127 | cellmatchlevel | cellmatchlevel | ✅ MATCH |
| 128 | cellreliabilitycode | cellreliabilitycode | ✅ MATCH |
| 129 | cellftcdonotcall | cellftcdonotcall | ✅ MATCH |
| 130 | cellappenddate | cellappenddate | ✅ MATCH |
| 131 | celldataaxle | celldataaxle | ✅ MATCH |
| 132 | celldataaxlematchlevel | celldataaxlematchlevel | ✅ MATCH |
| 133 | celldataaxlereliabilitycode | celldataaxlereliabilitycode | ✅ MATCH |
| 134 | celldataaxleftcdonotcall | celldataaxleftcdonotcall | ✅ MATCH |
| 135 | celldataaxleappenddate | celldataaxleappenddate | ✅ MATCH |
| 136 | cellrawvf | cellrawvf | ✅ MATCH |
| 137 | cellrawvf_firstobserved | cellrawvf_firstobserved | ✅ MATCH |
| 138 | cellabev | cellabev | ✅ MATCH |
| 139 | cellabev_firstobserved | cellabev_firstobserved | ✅ MATCH |
| 140 | cellneustar | cellneustar | ✅ MATCH |
| 141 | cellneustarmatchlevel | cellneustarmatchlevel | ✅ MATCH |
| 142 | cellneustarreliabilitycode | cellneustarreliabilitycode | ✅ MATCH |
| 143 | cellneustartimeofday | cellneustartimeofday | ✅ MATCH |
| 144 | cellneustarappenddate | cellneustarappenddate | ✅ MATCH |
| 145 | landline | landline | ✅ MATCH |
| 146 | landlinesourcecode | landlinesourcecode | ✅ MATCH |
| 147 | landlinematchlevel | landlinematchlevel | ✅ MATCH |
| 148 | landlinereliabilitycode | landlinereliabilitycode | ✅ MATCH |
| 149 | landlineftcdonotcall | landlineftcdonotcall | ✅ MATCH |
| 150 | landlineappenddate | landlineappenddate | ✅ MATCH |
| 151 | landlinedataaxle | landlinedataaxle | ✅ MATCH |
| 152 | landlinedataaxlematchlevel | landlinedataaxlematchlevel | ✅ MATCH |
| 153 | landlinedataaxlereliabilitycode | landlinedataaxlereliabilitycode | ✅ MATCH |
| 154 | landlinedataaxleftcdonotcall | landlinedataaxleftcdonotcall | ✅ MATCH |
| 155 | landlinedataaxleappenddate | landlinedataaxleappenddate | ✅ MATCH |
| 156 | landlinerawvf | landlinerawvf | ✅ MATCH |
| 157 | landlinerawvf_firstobserved | landlinerawvf_firstobserved | ✅ MATCH |
| 158 | landlineabev | landlineabev | ✅ MATCH |
| 159 | landlineabev_firstobserved | landlineabev_firstobserved | ✅ MATCH |
| 160 | landlineneustar | landlineneustar | ✅ MATCH |
| 161 | landlineneustarmatchlevel | landlineneustarmatchlevel | ✅ MATCH |
| 162 | landlineneustarreliabilitycode | landlineneustarreliabilitycode | ✅ MATCH |
| 163 | landlineneustartimeofday | landlineneustartimeofday | ✅ MATCH |
| 164 | landlineneustarappenddate | landlineneustarappenddate | ✅ MATCH |
| 165 | voterfrequencygeneral | voterfrequencygeneral | ✅ MATCH |
| 166 | voterfrequencyprimary | voterfrequencyprimary | ✅ MATCH |
| 167 | voterregularitygeneral | voterregularitygeneral | ✅ MATCH |
| 168 | voterregularityprimary | voterregularityprimary | ✅ MATCH |
| 169 | previousstate | previousstate | ✅ MATCH |
| 170 | previousstate_regid | previousstate_regid | ✅ MATCH |
| 171 | previousregparty | previousregparty | ✅ MATCH |
| 172 | firstobservedstate | firstobservedstate | ✅ MATCH |
| 173 | firstobservedstate_regid | firstobservedstate_regid | ✅ MATCH |
| 174 | firstobserveddate | firstobserveddate | ✅ MATCH |
| 175 | matchedmovestate | matchedmovestate | ✅ MATCH |
| 176 | matchedmovestate_regid | matchedmovestate_regid | ✅ MATCH |
| 177 | donorflag | donorflag | ✅ MATCH |
| 178 | mostrecentvote_state | mostrecentvote_state | ✅ MATCH |
| 179 | mostrecentvote_election | mostrecentvote_election | ✅ MATCH |
| 180 | mostrecentvote_method | mostrecentvote_method | ✅ MATCH |
| 181 | mostrecentvote_dte | mostrecentvote_dte | ✅ MATCH |
| 182 | vh26g | vh26g | ✅ MATCH — **2026 General: now has real data** |
| 183 | vh26p | vh26p | ✅ MATCH — **2026 Primary: now has real data** |
| 184 | vh25g | vh25g | ✅ MATCH |
| 185 | vh25p | vh25p | ✅ MATCH |
| 186 | vh24g | vh24g | ✅ MATCH |
| 187 | vh24p | vh24p | ✅ MATCH |
| 188 | vh24pp | vh24pp | ✅ MATCH |
| 189 | vh23g | vh23g | ✅ MATCH |
| 190 | vh23p | vh23p | ✅ MATCH |
| 191 | vh22g | vh22g | ✅ MATCH |
| 192 | vh22p | vh22p | ✅ MATCH |
| 193 | vh21g | vh21g | ✅ MATCH |
| 194 | vh21p | vh21p | ✅ MATCH |
| 195 | vh20g | vh20g | ✅ MATCH |
| 196 | vh20p | vh20p | ✅ MATCH |
| 197 | vh20pp | vh20pp | ✅ MATCH |
| 198 | vh19g | vh19g | ✅ MATCH |
| 199 | vh19p | vh19p | ✅ MATCH |
| 200 | vh18g | vh18g | ✅ MATCH |
| 201 | vh18p | vh18p | ✅ MATCH |
| 202 | vh17g | vh17g | ✅ MATCH |
| 203 | vh17p | vh17p | ✅ MATCH |
| 204 | vh16g | vh16g | ✅ MATCH |
| 205 | vh16p | vh16p | ✅ MATCH |
| 206 | vh16pp | vh16pp | ✅ MATCH |
| 207 | vh15g | vh15g | ✅ MATCH |
| 208 | vh15p | vh15p | ✅ MATCH |
| 209 | vh14g | vh14g | ✅ MATCH |
| 210 | vh14p | vh14p | ✅ MATCH |
| 211 | vh13g | vh13g | ✅ MATCH |
| 212 | vh13p | vh13p | ✅ MATCH |
| 213 | vh12g | vh12g | ✅ MATCH |
| 214 | vh12p | vh12p | ✅ MATCH |
| 215 | vh12pp | vh12pp | ✅ MATCH |
| 216 | vh11g | vh11g | ✅ MATCH |
| 217 | vh11p | vh11p | ✅ MATCH |
| 218 | vh10g | vh10g | ✅ MATCH |
| 219 | vh10p | vh10p | ✅ MATCH |
| 220 | vh09g | vh09g | ✅ MATCH |
| 221 | vh09p | vh09p | ✅ MATCH |
| 222 | vh08g | vh08g | ✅ MATCH |
| 223 | vh08p | vh08p | ✅ MATCH |
| 224 | vh08pp | vh08pp | ✅ MATCH |
| 225 | vh07g | vh07g | ✅ MATCH |
| 226 | vh07p | vh07p | ✅ MATCH |
| 227 | vh06g | vh06g | ✅ MATCH |
| 228 | vh06p | vh06p | ✅ MATCH |
| 229 | per24pres_gop | per24pres_gop | ✅ MATCH |
| 230 | per24pres_dem | per24pres_dem | ✅ MATCH |
| 231 | per24pres_oth | per24pres_oth | ✅ MATCH |
| 232 | coalitionid_socialconservative | coalitionid_socialconservative | ✅ MATCH |
| 233 | coalitionid_veteran | coalitionid_veteran | ✅ MATCH |
| 234 | coalitionid_sportsmen | coalitionid_sportsmen | ✅ MATCH |
| 235 | coalitionid_2ndamendment | coalitionid_2ndamendment | ✅ MATCH |
| 236 | coalitionid_prolife | coalitionid_prolife | ✅ MATCH |
| 237 | coalitionid_prochoice | coalitionid_prochoice | ✅ MATCH |
| 238 | coalitionid_fiscalconservative | coalitionid_fiscalconservative | ✅ MATCH |
| 239 | republicanpartyscore | republicanpartyscore | ✅ MATCH |
| 240 | democraticpartyscore | democraticpartyscore | ✅ MATCH |
| 241 | republicanballotscore | republicanballotscore | ✅ MATCH |
| 242 | democraticballotscore | democraticballotscore | ✅ MATCH |
| 243 | turnoutgeneralscore | turnoutgeneralscore | ✅ MATCH |
| 244 | householdincomemodeled | householdincomemodeled | ✅ MATCH |
| 245 | educationmodeled | educationmodeled | ✅ MATCH |
| 246 | custom01 | custom01 | ✅ MATCH |
| 247 | custom02 | custom02 | ✅ MATCH |
| 248 | custom03 | custom03 | ✅ MATCH |
| 249 | custom04 | custom04 | ✅ MATCH |
| 250 | custom05 | custom05 | ✅ MATCH |
| 251 | lastupdate | lastupdate | ✅ MATCH |

---

## Section 5: Top 25 High-Value Columns Getting Fresh Data

This is a March 2026 build — these columns carry the most strategic value from the refresh:

### 🗳️ Vote History (highest priority — 2026 elections now populated)
| Column | Why It Matters |
|--------|---------------|
| `vh26g` | 2026 General Election turnout — brand new, was empty/placeholder before |
| `vh26p` | 2026 Primary Election turnout — same |
| `vh25g` | 2025 General refreshed |
| `vh25p` | 2025 Primary refreshed |
| `mostrecentvote_election` | Now reflects 2025/2026 elections for active voters |
| `mostrecentvote_dte` | Most recent vote date updated |
| `voterfrequencygeneral` | Recomputed with 2026 cycle included |
| `voterfrequencyprimary` | Recomputed with 2026 cycle included |
| `voterregularitygeneral` | Recomputed — critical for targeting "reliable" Rs |
| `voterregularityprimary` | Recomputed |

### 📱 Phone Numbers (second highest priority — donor outreach + GOTV)
| Column | Why It Matters |
|--------|---------------|
| `cell` | Primary cell — refreshed from multiple append sources |
| `cellappenddate` | Tells you how fresh the cell match is |
| `cellreliabilitycode` | Quality signal — filter low-reliability numbers |
| `celldataaxle` | Secondary cell from Data Axle append |
| `cellneustar` | Tertiary cell from Neustar — fills gaps |
| `landline` | Still useful for older voters |
| `landlineappenddate` | Freshness indicator |

### 🎯 Scores (re-modeled with 2026 cycle data)
| Column | Why It Matters |
|--------|---------------|
| `republicanpartyscore` | Re-scored — 2026 behavior baked in |
| `turnoutgeneralscore` | Critical for GOTV targeting |
| `republicanballotscore` | Straight-ticket R likelihood |
| `coalitionid_socialconservative` | Coalition targeting |
| `coalitionid_2ndamendment` | Coalition targeting |
| `coalitionid_prolife` | Coalition targeting |
| `modeledparty` | Re-modeled with updated behavior |

### 🏛️ District Lines (renamed — real data update)
| Column | Why It Matters |
|--------|---------------|
| `statelegsupperdistrict` | NC Senate district — updated post-redistricting |
| `stateleglowerdistrict` | NC House district — updated post-redistricting |
| `congressionaldistrict` | CD refreshed |

---

## Section 6: ALTER TABLE Statements

Only 4 renames needed. No new columns to add — the fresh file fits the existing schema.

```sql
-- Step 1: Rename the 4 upper district columns to match new DataTrust naming
-- Run these BEFORE the UPDATE merge

ALTER TABLE public.nc_datatrust
  RENAME COLUMN statelegupperdistrict TO statelegsupperdistrict;

ALTER TABLE public.nc_datatrust
  RENAME COLUMN statelegupperdistrict_previouselection TO statelegsupperdistrict_previouselection;

ALTER TABLE public.nc_datatrust
  RENAME COLUMN statelegupperdistrict_proper TO statelegsupperdistrict_proper;

ALTER TABLE public.nc_datatrust
  RENAME COLUMN statelegupperdistrict_proper_previouselection TO statelegsupperdistrict_proper_previouselection;

-- Verify rename succeeded
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public'
  AND table_name = 'nc_datatrust'
  AND column_name LIKE 'stateleg%upper%'
ORDER BY ordinal_position;
-- Should return 4 rows all starting with 'statelegs'
```

---

## Section 7: UPDATE Merge Statement

Merges all 251 DataTrust columns from staging → production using rncid as the join key. Preserves the 5 norm_ columns we added (they are not in the SET clause).

**Estimated rows affected:** ~7.6M (existing) + net new registrants since last load

```sql
-- Step 2: Merge staging.nc_voters_fresh into public.nc_datatrust
-- Join key: rncid
-- This UPDATE touches only existing rows. See Step 3 for new registrants.

UPDATE public.nc_datatrust dt
SET
  rnc_regid = f.rnc_regid,
  prev_rncid = f.prev_rncid,
  state = f.state,
  statekey = f.statekey,
  ispartyreg = f.ispartyreg,
  sourceid = f.sourceid,
  juriscode = f.juriscode,
  jurisname = f.jurisname,
  countyfips = f.countyfips,
  countyname = f.countyname,
  mediamarket = f.mediamarket,
  censusblock2020 = f.censusblock2020,
  metrotype = f.metrotype,
  mcd = f.mcd,
  statecountycode = f.statecountycode,
  statetowncode = f.statetowncode,
  ward = f.ward,
  precinctcode = f.precinctcode,
  precinctname = f.precinctname,
  ballotbox = f.ballotbox,
  schoolboard = f.schoolboard,
  schooldistrict = f.schooldistrict,
  citycouncil = f.citycouncil,
  countycommissioner = f.countycommissioner,
  congressionaldistrict = f.congressionaldistrict,
  congressionaldistrict_previouselection = f.congressionaldistrict_previouselection,
  statelegsupperdistrict = f.statelegsupperdistrict,
  statelegsupperdistrict_previouselection = f.statelegsupperdistrict_previouselection,
  statelegsupperdistrict_proper = f.statelegsupperdistrict_proper,
  statelegsupperdistrict_proper_previouselection = f.statelegsupperdistrict_proper_previouselection,
  stateleglowerdistrict = f.stateleglowerdistrict,
  stateleglowerdistrict_previouselection = f.stateleglowerdistrict_previouselection,
  stateleglowersubdistrict = f.stateleglowersubdistrict,
  stateleglowersubdistrict_previouselection = f.stateleglowersubdistrict_previouselection,
  stateleglowerdistrict_proper = f.stateleglowerdistrict_proper,
  stateleglowerdistrict_proper_previouselection = f.stateleglowerdistrict_proper_previouselection,
  nameprefix = f.nameprefix,
  firstname = f.firstname,
  middlename = f.middlename,
  lastname = f.lastname,
  namesuffix = f.namesuffix,
  sex = f.sex,
  birthyear = f.birthyear,
  birthmonth = f.birthmonth,
  birthday = f.birthday,
  age = f.age,
  agerange = f.agerange,
  congressionalagerange = f.congressionalagerange,
  registeredparty = f.registeredparty,
  partyrollup = f.partyrollup,
  calcparty = f.calcparty,
  modeledparty = f.modeledparty,
  statevoterid = f.statevoterid,
  jurisdictionvoterid = f.jurisdictionvoterid,
  lastactivitydate = f.lastactivitydate,
  registrationdate = f.registrationdate,
  registrationdatesource = f.registrationdatesource,
  voterstatus = f.voterstatus,
  permanentabsentee = f.permanentabsentee,
  ethnicityreported = f.ethnicityreported,
  ethnicitymodeled = f.ethnicitymodeled,
  ethnicgroupmodeled = f.ethnicgroupmodeled,
  ethnicgroupnamemodeled = f.ethnicgroupnamemodeled,
  religionmodeled = f.religionmodeled,
  languagemodeled = f.languagemodeled,
  acsethnicity_white = f.acsethnicity_white,
  acsethnicity_black = f.acsethnicity_black,
  acsethnicity_hispanic = f.acsethnicity_hispanic,
  acsethnicity_asian = f.acsethnicity_asian,
  acsethnicity_other = f.acsethnicity_other,
  acseducation_highschool = f.acseducation_highschool,
  acseducation_college = f.acseducation_college,
  acseducation_graduate = f.acseducation_graduate,
  acseducation_vocational = f.acseducation_vocational,
  acseducation_none = f.acseducation_none,
  householdid = f.householdid,
  householdmemberid = f.householdmemberid,
  householdparty = f.householdparty,
  registrationaddr1 = f.registrationaddr1,
  registrationaddr2 = f.registrationaddr2,
  reghousenum = f.reghousenum,
  reghousesfx = f.reghousesfx,
  regstprefix = f.regstprefix,
  regstname = f.regstname,
  regsttype = f.regsttype,
  regstpost = f.regstpost,
  regunittype = f.regunittype,
  regunitnumber = f.regunitnumber,
  regcity = f.regcity,
  regsta = f.regsta,
  regzip5 = f.regzip5,
  regzip4 = f.regzip4,
  reglatitude = f.reglatitude,
  reglongitude = f.reglongitude,
  reggeocodelevel = f.reggeocodelevel,
  reglastcleanse = f.reglastcleanse,
  reglastgeocode = f.reglastgeocode,
  reglastcoa = f.reglastcoa,
  changeofaddresssource = f.changeofaddresssource,
  changeofaddressdate = f.changeofaddressdate,
  changeofaddresstype = f.changeofaddresstype,
  mailingaddr1 = f.mailingaddr1,
  mailingaddr2 = f.mailingaddr2,
  mailhousenum = f.mailhousenum,
  mailhousesfx = f.mailhousesfx,
  mailstprefix = f.mailstprefix,
  mailstname = f.mailstname,
  mailsttype = f.mailsttype,
  mailstpost = f.mailstpost,
  mailunittype = f.mailunittype,
  mailunitnumber = f.mailunitnumber,
  mailcity = f.mailcity,
  mailsta = f.mailsta,
  mailzip5 = f.mailzip5,
  mailzip4 = f.mailzip4,
  mailsortcoderoute = f.mailsortcoderoute,
  maildeliverypt = f.maildeliverypt,
  maildeliveryptchkdigit = f.maildeliveryptchkdigit,
  maillineoftravel = f.maillineoftravel,
  maillineoftravelorder = f.maillineoftravelorder,
  maildpvstatus = f.maildpvstatus,
  maillastcleanse = f.maillastcleanse,
  maillastcoa = f.maillastcoa,
  cell = f.cell,
  cellsourcecode = f.cellsourcecode,
  cellmatchlevel = f.cellmatchlevel,
  cellreliabilitycode = f.cellreliabilitycode,
  cellftcdonotcall = f.cellftcdonotcall,
  cellappenddate = f.cellappenddate,
  celldataaxle = f.celldataaxle,
  celldataaxlematchlevel = f.celldataaxlematchlevel,
  celldataaxlereliabilitycode = f.celldataaxlereliabilitycode,
  celldataaxleftcdonotcall = f.celldataaxleftcdonotcall,
  celldataaxleappenddate = f.celldataaxleappenddate,
  cellrawvf = f.cellrawvf,
  cellrawvf_firstobserved = f.cellrawvf_firstobserved,
  cellabev = f.cellabev,
  cellabev_firstobserved = f.cellabev_firstobserved,
  cellneustar = f.cellneustar,
  cellneustarmatchlevel = f.cellneustarmatchlevel,
  cellneustarreliabilitycode = f.cellneustarreliabilitycode,
  cellneustartimeofday = f.cellneustartimeofday,
  cellneustarappenddate = f.cellneustarappenddate,
  landline = f.landline,
  landlinesourcecode = f.landlinesourcecode,
  landlinematchlevel = f.landlinematchlevel,
  landlinereliabilitycode = f.landlinereliabilitycode,
  landlineftcdonotcall = f.landlineftcdonotcall,
  landlineappenddate = f.landlineappenddate,
  landlinedataaxle = f.landlinedataaxle,
  landlinedataaxlematchlevel = f.landlinedataaxlematchlevel,
  landlinedataaxlereliabilitycode = f.landlinedataaxlereliabilitycode,
  landlinedataaxleftcdonotcall = f.landlinedataaxleftcdonotcall,
  landlinedataaxleappenddate = f.landlinedataaxleappenddate,
  landlinerawvf = f.landlinerawvf,
  landlinerawvf_firstobserved = f.landlinerawvf_firstobserved,
  landlineabev = f.landlineabev,
  landlineabev_firstobserved = f.landlineabev_firstobserved,
  landlineneustar = f.landlineneustar,
  landlineneustarmatchlevel = f.landlineneustarmatchlevel,
  landlineneustarreliabilitycode = f.landlineneustarreliabilitycode,
  landlineneustartimeofday = f.landlineneustartimeofday,
  landlineneustarappenddate = f.landlineneustarappenddate,
  voterfrequencygeneral = f.voterfrequencygeneral,
  voterfrequencyprimary = f.voterfrequencyprimary,
  voterregularitygeneral = f.voterregularitygeneral,
  voterregularityprimary = f.voterregularityprimary,
  previousstate = f.previousstate,
  previousstate_regid = f.previousstate_regid,
  previousregparty = f.previousregparty,
  firstobservedstate = f.firstobservedstate,
  firstobservedstate_regid = f.firstobservedstate_regid,
  firstobserveddate = f.firstobserveddate,
  matchedmovestate = f.matchedmovestate,
  matchedmovestate_regid = f.matchedmovestate_regid,
  donorflag = f.donorflag,
  mostrecentvote_state = f.mostrecentvote_state,
  mostrecentvote_election = f.mostrecentvote_election,
  mostrecentvote_method = f.mostrecentvote_method,
  mostrecentvote_dte = f.mostrecentvote_dte,
  vh26g = f.vh26g,
  vh26p = f.vh26p,
  vh25g = f.vh25g,
  vh25p = f.vh25p,
  vh24g = f.vh24g,
  vh24p = f.vh24p,
  vh24pp = f.vh24pp,
  vh23g = f.vh23g,
  vh23p = f.vh23p,
  vh22g = f.vh22g,
  vh22p = f.vh22p,
  vh21g = f.vh21g,
  vh21p = f.vh21p,
  vh20g = f.vh20g,
  vh20p = f.vh20p,
  vh20pp = f.vh20pp,
  vh19g = f.vh19g,
  vh19p = f.vh19p,
  vh18g = f.vh18g,
  vh18p = f.vh18p,
  vh17g = f.vh17g,
  vh17p = f.vh17p,
  vh16g = f.vh16g,
  vh16p = f.vh16p,
  vh16pp = f.vh16pp,
  vh15g = f.vh15g,
  vh15p = f.vh15p,
  vh14g = f.vh14g,
  vh14p = f.vh14p,
  vh13g = f.vh13g,
  vh13p = f.vh13p,
  vh12g = f.vh12g,
  vh12p = f.vh12p,
  vh12pp = f.vh12pp,
  vh11g = f.vh11g,
  vh11p = f.vh11p,
  vh10g = f.vh10g,
  vh10p = f.vh10p,
  vh09g = f.vh09g,
  vh09p = f.vh09p,
  vh08g = f.vh08g,
  vh08p = f.vh08p,
  vh08pp = f.vh08pp,
  vh07g = f.vh07g,
  vh07p = f.vh07p,
  vh06g = f.vh06g,
  vh06p = f.vh06p,
  per24pres_gop = f.per24pres_gop,
  per24pres_dem = f.per24pres_dem,
  per24pres_oth = f.per24pres_oth,
  coalitionid_socialconservative = f.coalitionid_socialconservative,
  coalitionid_veteran = f.coalitionid_veteran,
  coalitionid_sportsmen = f.coalitionid_sportsmen,
  coalitionid_2ndamendment = f.coalitionid_2ndamendment,
  coalitionid_prolife = f.coalitionid_prolife,
  coalitionid_prochoice = f.coalitionid_prochoice,
  coalitionid_fiscalconservative = f.coalitionid_fiscalconservative,
  republicanpartyscore = f.republicanpartyscore,
  democraticpartyscore = f.democraticpartyscore,
  republicanballotscore = f.republicanballotscore,
  democraticballotscore = f.democraticballotscore,
  turnoutgeneralscore = f.turnoutgeneralscore,
  householdincomemodeled = f.householdincomemodeled,
  educationmodeled = f.educationmodeled,
  custom01 = f.custom01,
  custom02 = f.custom02,
  custom03 = f.custom03,
  custom04 = f.custom04,
  custom05 = f.custom05,
  lastupdate = f.lastupdate
FROM staging.nc_voters_fresh f
WHERE dt.rncid = f.rncid;

-- NOTE: norm_first, norm_last, norm_zip5, addr_type, norm_street_num are intentionally
-- excluded from SET — these are our derived columns and must not be overwritten.
```

---

## Section 8: Step 3 — Insert New Registrants

Rows in the fresh file with no matching rncid in nc_datatrust are new registrants since the last load. Insert them with NULL norm_ columns (to be recomputed after merge).

```sql
-- Step 3: Insert brand-new registrants (rncid not yet in nc_datatrust)
INSERT INTO public.nc_datatrust (
  rncid, rnc_regid, prev_rncid, state, statekey, ispartyreg, sourceid,
  juriscode, jurisname, countyfips, countyname, mediamarket, censusblock2020,
  metrotype, mcd, statecountycode, statetowncode, ward, precinctcode, precinctname,
  ballotbox, schoolboard, schooldistrict, citycouncil, countycommissioner,
  congressionaldistrict, congressionaldistrict_previouselection,
  statelegsupperdistrict, statelegsupperdistrict_previouselection,
  statelegsupperdistrict_proper, statelegsupperdistrict_proper_previouselection,
  stateleglowerdistrict, stateleglowerdistrict_previouselection,
  stateleglowersubdistrict, stateleglowersubdistrict_previouselection,
  stateleglowerdistrict_proper, stateleglowerdistrict_proper_previouselection,
  nameprefix, firstname, middlename, lastname, namesuffix,
  sex, birthyear, birthmonth, birthday, age, agerange, congressionalagerange,
  registeredparty, partyrollup, calcparty, modeledparty,
  statevoterid, jurisdictionvoterid, lastactivitydate, registrationdate,
  registrationdatesource, voterstatus, permanentabsentee,
  ethnicityreported, ethnicitymodeled, ethnicgroupmodeled, ethnicgroupnamemodeled,
  religionmodeled, languagemodeled,
  acsethnicity_white, acsethnicity_black, acsethnicity_hispanic,
  acsethnicity_asian, acsethnicity_other,
  acseducation_highschool, acseducation_college, acseducation_graduate,
  acseducation_vocational, acseducation_none,
  householdid, householdmemberid, householdparty,
  registrationaddr1, registrationaddr2, reghousenum, reghousesfx,
  regstprefix, regstname, regsttype, regstpost, regunittype, regunitnumber,
  regcity, regsta, regzip5, regzip4, reglatitude, reglongitude,
  reggeocodelevel, reglastcleanse, reglastgeocode, reglastcoa,
  changeofaddresssource, changeofaddressdate, changeofaddresstype,
  mailingaddr1, mailingaddr2, mailhousenum, mailhousesfx,
  mailstprefix, mailstname, mailsttype, mailstpost, mailunittype, mailunitnumber,
  mailcity, mailsta, mailzip5, mailzip4, mailsortcoderoute,
  maildeliverypt, maildeliveryptchkdigit, maillineoftravel, maillineoftravelorder,
  maildpvstatus, maillastcleanse, maillastcoa,
  cell, cellsourcecode, cellmatchlevel, cellreliabilitycode, cellftcdonotcall,
  cellappenddate, celldataaxle, celldataaxlematchlevel, celldataaxlereliabilitycode,
  celldataaxleftcdonotcall, celldataaxleappenddate,
  cellrawvf, cellrawvf_firstobserved, cellabev, cellabev_firstobserved,
  cellneustar, cellneustarmatchlevel, cellneustarreliabilitycode,
  cellneustartimeofday, cellneustarappenddate,
  landline, landlinesourcecode, landlinematchlevel, landlinereliabilitycode,
  landlineftcdonotcall, landlineappenddate, landlinedataaxle,
  landlinedataaxlematchlevel, landlinedataaxlereliabilitycode,
  landlinedataaxleftcdonotcall, landlinedataaxleappenddate,
  landlinerawvf, landlinerawvf_firstobserved, landlineabev, landlineabev_firstobserved,
  landlineneustar, landlineneustarmatchlevel, landlineneustarreliabilitycode,
  landlineneustartimeofday, landlineneustarappenddate,
  voterfrequencygeneral, voterfrequencyprimary, voterregularitygeneral, voterregularityprimary,
  previousstate, previousstate_regid, previousregparty,
  firstobservedstate, firstobservedstate_regid, firstobserveddate,
  matchedmovestate, matchedmovestate_regid, donorflag,
  mostrecentvote_state, mostrecentvote_election, mostrecentvote_method, mostrecentvote_dte,
  vh26g, vh26p, vh25g, vh25p, vh24g, vh24p, vh24pp,
  vh23g, vh23p, vh22g, vh22p, vh21g, vh21p,
  vh20g, vh20p, vh20pp, vh19g, vh19p, vh18g, vh18p,
  vh17g, vh17p, vh16g, vh16p, vh16pp, vh15g, vh15p,
  vh14g, vh14p, vh13g, vh13p, vh12g, vh12p, vh12pp,
  vh11g, vh11p, vh10g, vh10p, vh09g, vh09p,
  vh08g, vh08p, vh08pp, vh07g, vh07p, vh06g, vh06p,
  per24pres_gop, per24pres_dem, per24pres_oth,
  coalitionid_socialconservative, coalitionid_veteran, coalitionid_sportsmen,
  coalitionid_2ndamendment, coalitionid_prolife, coalitionid_prochoice,
  coalitionid_fiscalconservative,
  republicanpartyscore, democraticpartyscore, republicanballotscore,
  democraticballotscore, turnoutgeneralscore,
  householdincomemodeled, educationmodeled,
  custom01, custom02, custom03, custom04, custom05, lastupdate
)
SELECT
  rncid, rnc_regid, prev_rncid, state, statekey, ispartyreg, sourceid,
  juriscode, jurisname, countyfips, countyname, mediamarket, censusblock2020,
  metrotype, mcd, statecountycode, statetowncode, ward, precinctcode, precinctname,
  ballotbox, schoolboard, schooldistrict, citycouncil, countycommissioner,
  congressionaldistrict, congressionaldistrict_previouselection,
  statelegsupperdistrict, statelegsupperdistrict_previouselection,
  statelegsupperdistrict_proper, statelegsupperdistrict_proper_previouselection,
  stateleglowerdistrict, stateleglowerdistrict_previouselection,
  stateleglowersubdistrict, stateleglowersubdistrict_previouselection,
  stateleglowerdistrict_proper, stateleglowerdistrict_proper_previouselection,
  nameprefix, firstname, middlename, lastname, namesuffix,
  sex, birthyear, birthmonth, birthday, age, agerange, congressionalagerange,
  registeredparty, partyrollup, calcparty, modeledparty,
  statevoterid, jurisdictionvoterid, lastactivitydate, registrationdate,
  registrationdatesource, voterstatus, permanentabsentee,
  ethnicityreported, ethnicitymodeled, ethnicgroupmodeled, ethnicgroupnamemodeled,
  religionmodeled, languagemodeled,
  acsethnicity_white, acsethnicity_black, acsethnicity_hispanic,
  acsethnicity_asian, acsethnicity_other,
  acseducation_highschool, acseducation_college, acseducation_graduate,
  acseducation_vocational, acseducation_none,
  householdid, householdmemberid, householdparty,
  registrationaddr1, registrationaddr2, reghousenum, reghousesfx,
  regstprefix, regstname, regsttype, regstpost, regunittype, regunitnumber,
  regcity, regsta, regzip5, regzip4, reglatitude, reglongitude,
  reggeocodelevel, reglastcleanse, reglastgeocode, reglastcoa,
  changeofaddresssource, changeofaddressdate, changeofaddresstype,
  mailingaddr1, mailingaddr2, mailhousenum, mailhousesfx,
  mailstprefix, mailstname, mailsttype, mailstpost, mailunittype, mailunitnumber,
  mailcity, mailsta, mailzip5, mailzip4, mailsortcoderoute,
  maildeliverypt, maildeliveryptchkdigit, maillineoftravel, maillineoftravelorder,
  maildpvstatus, maillastcleanse, maillastcoa,
  cell, cellsourcecode, cellmatchlevel, cellreliabilitycode, cellftcdonotcall,
  cellappenddate, celldataaxle, celldataaxlematchlevel, celldataaxlereliabilitycode,
  celldataaxleftcdonotcall, celldataaxleappenddate,
  cellrawvf, cellrawvf_firstobserved, cellabev, cellabev_firstobserved,
  cellneustar, cellneustarmatchlevel, cellneustarreliabilitycode,
  cellneustartimeofday, cellneustarappenddate,
  landline, landlinesourcecode, landlinematchlevel, landlinereliabilitycode,
  landlineftcdonotcall, landlineappenddate, landlinedataaxle,
  landlinedataaxlematchlevel, landlinedataaxlereliabilitycode,
  landlinedataaxleftcdonotcall, landlinedataaxleappenddate,
  landlinerawvf, landlinerawvf_firstobserved, landlineabev, landlineabev_firstobserved,
  landlineneustar, landlineneustarmatchlevel, landlineneustarreliabilitycode,
  landlineneustartimeofday, landlineneustarappenddate,
  voterfrequencygeneral, voterfrequencyprimary, voterregularitygeneral, voterregularityprimary,
  previousstate, previousstate_regid, previousregparty,
  firstobservedstate, firstobservedstate_regid, firstobserveddate,
  matchedmovestate, matchedmovestate_regid, donorflag,
  mostrecentvote_state, mostrecentvote_election, mostrecentvote_method, mostrecentvote_dte,
  vh26g, vh26p, vh25g, vh25p, vh24g, vh24p, vh24pp,
  vh23g, vh23p, vh22g, vh22p, vh21g, vh21p,
  vh20g, vh20p, vh20pp, vh19g, vh19p, vh18g, vh18p,
  vh17g, vh17p, vh16g, vh16p, vh16pp, vh15g, vh15p,
  vh14g, vh14p, vh13g, vh13p, vh12g, vh12p, vh12pp,
  vh11g, vh11p, vh10g, vh10p, vh09g, vh09p,
  vh08g, vh08p, vh08pp, vh07g, vh07p, vh06g, vh06p,
  per24pres_gop, per24pres_dem, per24pres_oth,
  coalitionid_socialconservative, coalitionid_veteran, coalitionid_sportsmen,
  coalitionid_2ndamendment, coalitionid_prolife, coalitionid_prochoice,
  coalitionid_fiscalconservative,
  republicanpartyscore, democraticpartyscore, republicanballotscore,
  democraticballotscore, turnoutgeneralscore,
  householdincomemodeled, educationmodeled,
  custom01, custom02, custom03, custom04, custom05, lastupdate
FROM staging.nc_voters_fresh f
WHERE NOT EXISTS (
  SELECT 1 FROM public.nc_datatrust dt WHERE dt.rncid = f.rncid
);
```

---

## Section 9: Post-Merge Verification Queries

Run these after Perplexity approves and execution completes:

```sql
-- 1. Row counts
SELECT COUNT(*) FROM public.nc_datatrust;          -- Expect ~9M+
SELECT COUNT(*) FROM staging.nc_voters_fresh;       -- Expect ~9M
SELECT COUNT(*) FROM public.nc_datatrust WHERE vh26g IS NOT NULL; -- 2026 turnout filled?

-- 2. Confirm renames worked
SELECT column_name FROM information_schema.columns
WHERE table_schema = 'public' AND table_name = 'nc_datatrust'
  AND column_name LIKE 'stateleg%upper%';
-- Should show 4 rows with 'statelegs' prefix

-- 3. Confirm norm_ columns preserved
SELECT COUNT(*) FROM public.nc_datatrust WHERE norm_first IS NOT NULL;

-- 4. Spot-check phone freshness
SELECT COUNT(*) FROM public.nc_datatrust WHERE cell IS NOT NULL;
SELECT COUNT(*) FROM public.nc_datatrust WHERE cellappenddate > '2025-01-01';

-- 5. Spot-check 2026 vote history
SELECT vh26g, COUNT(*) FROM public.nc_datatrust GROUP BY vh26g ORDER BY COUNT(*) DESC LIMIT 5;
SELECT vh26p, COUNT(*) FROM public.nc_datatrust GROUP BY vh26p ORDER BY COUNT(*) DESC LIMIT 5;
```

---

## Section 10: Unmatched Row Strategy

### Case A: Rows in nc_datatrust with NO match in staging.nc_voters_fresh
These are voters who existed in the old file but are absent from the March 2026 build. This can mean:
- Voter has moved out of NC (purged by SBOE)
- Voter has died
- Voter was merged/deduped by DataTrust under a new RNCID

**Recommended action: DO NOT DELETE.** Retain these rows in nc_datatrust as-is. They represent historical NC voter registrations that may still be referenced by donation records, ecosystem queries, and person_source_links. Flag them optionally with a new column `file_absent_since` (future enhancement).

**To identify unmatched nc_datatrust rows (DRY RUN only):**
```sql
-- Count nc_datatrust rows not in fresh file
SELECT COUNT(*) as orphaned_rows
FROM public.nc_datatrust dt
WHERE NOT EXISTS (
  SELECT 1 FROM staging.nc_voters_fresh f WHERE f.rncid = dt.rncid
);
```

### Case B: Rows in staging.nc_voters_fresh with NO match in nc_datatrust
These are new registrants who appear in DataTrust for the first time (registered since last load, or newly matched/assigned an RNCID).

**Recommended action: INSERT** via the Section 8 INSERT statement. Their norm_ columns will be NULL and must be recomputed after the merge by re-running the name normalization job.

**To identify new registrants (DRY RUN only):**
```sql
-- Count fresh rows not yet in nc_datatrust
SELECT COUNT(*) as new_registrants
FROM staging.nc_voters_fresh f
WHERE NOT EXISTS (
  SELECT 1 FROM public.nc_datatrust dt WHERE dt.rncid = f.rncid
);
```

### Case C: StateVoterID as Secondary Join
If RNCID matching produces unexpected gaps (e.g., DataTrust reassigned RNCIDs), statevoterid (column 54) can serve as a fallback. This is a NC Board of Elections-issued ID that is stable across DataTrust refreshes.

```sql
-- Fallback match check: rows where RNCID differs but StateVoterID matches
-- Use this as a diagnostic only, not for production update
SELECT f.rncid as fresh_rncid, dt.rncid as old_rncid,
       f.statevoterid, f.firstname, f.lastname
FROM staging.nc_voters_fresh f
JOIN public.nc_datatrust dt ON dt.statevoterid = f.statevoterid
WHERE f.rncid != dt.rncid
LIMIT 100;
-- If this returns rows, report to Perplexity before proceeding.
-- RNCID reassignments require special handling.
```

---

## Section 11: Execution Order Summary

```
PHASE 0 — WAIT (no SQL yet)
  1. Confirm voter file download complete on Hetzner
  2. Confirm staging.nc_voters_fresh row count ~9M
  3. Confirm this plan committed to GitHub sessions/NC_DATATRUST_MIGRATION_PLAN.md

PHASE 1 — DRY RUN (SELECT only, no changes)
  4. Run Case A count (Section 10) — orphaned rows in nc_datatrust
  5. Run Case B count (Section 10) — new registrants in fresh
  6. Run Case C check (Section 10) — RNCID reassignment diagnostic
  7. Report counts to Perplexity and Eddie for review

PHASE 2 — EXECUTION (requires "I authorize this action" from Ed)
  8. Run ALTER TABLE renames (Section 6) — 4 column renames, fast
  9. Run UPDATE merge (Section 7) — ~9M rows, expect 15-45 min
  10. Run INSERT new registrants (Section 8)
  11. Run verification queries (Section 9)
  12. Update SESSION-STATE.md
```

---

*Prepared by Claude | April 2, 2026 | DO NOT EXECUTE without Perplexity sign-off*
