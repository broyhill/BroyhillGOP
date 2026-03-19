# NC Voter File Schema

Reference for `public.nc_voters` (~9.1M rows). Source: NC State Board of Elections (NCSBE).  
**Layout:** https://s3.amazonaws.com/dl.ncsbe.gov/data/layout_ncvoter.txt  
**Format:** Tab-delimited; updated weekly (Saturday).

---

## CREATE TABLE (PostgreSQL)

```sql
CREATE TABLE public.nc_voters (
    county_id INTEGER,
    county_desc TEXT,
    voter_reg_num TEXT,
    ncid TEXT PRIMARY KEY,
    last_name TEXT,
    first_name TEXT,
    middle_name TEXT,
    name_suffix_lbl TEXT,
    status_cd TEXT,
    voter_status_desc TEXT,
    reason_cd TEXT,
    voter_status_reason_desc TEXT,
    res_street_address TEXT,
    res_city_desc TEXT,
    state_cd TEXT,
    zip_code TEXT,
    mail_addr1 TEXT,
    mail_addr2 TEXT,
    mail_addr3 TEXT,
    mail_addr4 TEXT,
    mail_city TEXT,
    mail_state TEXT,
    mail_zipcode TEXT,
    full_phone_number TEXT,
    confidential_ind TEXT,
    registr_dt TEXT,
    race_code TEXT,
    ethnic_code TEXT,
    party_cd TEXT,
    gender_code TEXT,
    birth_year TEXT,
    age_at_year_end TEXT,
    birth_state TEXT,
    drivers_lic TEXT,
    precinct_abbrv TEXT,
    precinct_desc TEXT,
    municipality_abbrv TEXT,
    municipality_desc TEXT,
    ward_abbrv TEXT,
    ward_desc TEXT,
    cong_dist_abbrv TEXT,
    super_court_abbrv TEXT,
    judic_dist_abbrv TEXT,
    nc_senate_abbrv TEXT,
    nc_house_abbrv TEXT,
    county_commis_abbrv TEXT,
    county_commis_desc TEXT,
    township_abbrv TEXT,
    township_desc TEXT,
    school_dist_abbrv TEXT,
    school_dist_desc TEXT,
    fire_dist_abbrv TEXT,
    fire_dist_desc TEXT,
    water_dist_abbrv TEXT,
    water_dist_desc TEXT,
    sewer_dist_abbrv TEXT,
    sewer_dist_desc TEXT,
    sanit_dist_abbrv TEXT,
    sanit_dist_desc TEXT,
    rescue_dist_abbrv TEXT,
    rescue_dist_desc TEXT,
    munic_dist_abbrv TEXT,
    munic_dist_desc TEXT,
    dist_1_abbrv TEXT,
    dist_1_desc TEXT,
    vtd_abbrv TEXT,
    vtd_desc TEXT
);

-- Recommended indexes (Master Plan §0.1)
CREATE UNIQUE INDEX IF NOT EXISTS idx_nc_voters_ncid ON public.nc_voters(ncid);
CREATE INDEX IF NOT EXISTS idx_nc_voters_last_name ON public.nc_voters(last_name);
CREATE INDEX IF NOT EXISTS idx_nc_voters_zip_code ON public.nc_voters(zip_code);
CREATE INDEX IF NOT EXISTS idx_nc_voters_county_desc ON public.nc_voters(county_desc);
```

---

## All 67 columns (name, type, description)

| # | Column | Type | Description |
|---|--------|------|-------------|
| 1 | county_id | int | County identification number (1-100) |
| 2 | county_desc | varchar(15) | County name |
| 3 | voter_reg_num | char(12) | Voter registration number (unique to county) |
| 4 | ncid | char(12) | North Carolina ID (statewide unique) |
| 5 | last_name | varchar(25) | Voter last name |
| 6 | first_name | varchar(20) | Voter first name |
| 7 | middle_name | varchar(20) | Voter middle name |
| 8 | name_suffix_lbl | char(3) | Suffix (JR, III, etc.) |
| 9 | status_cd | char(2) | Registration status code |
| 10 | voter_status_desc | varchar(25) | Status description |
| 11 | reason_cd | varchar(2) | Status reason code |
| 12 | voter_status_reason_desc | varchar(60) | Status reason description |
| 13 | res_street_address | varchar(65) | Residential street address |
| 14 | res_city_desc | varchar(60) | Residential city |
| 15 | state_cd | varchar(2) | Residential state code |
| 16 | zip_code | char(9) | Residential zip code |
| 17 | mail_addr1 | varchar(40) | Mailing address line 1 |
| 18 | mail_addr2 | varchar(40) | Mailing address line 2 |
| 19 | mail_addr3 | varchar(40) | Mailing address line 3 |
| 20 | mail_addr4 | varchar(40) | Mailing address line 4 |
| 21 | mail_city | varchar(30) | Mailing city |
| 22 | mail_state | varchar(2) | Mailing state |
| 23 | mail_zipcode | char(9) | Mailing zip code |
| 24 | full_phone_number | varchar(12) | Phone with area code |
| 25 | confidential_ind | char(1) | Confidential indicator |
| 26 | registr_dt | char(10) | Registration date |
| 27 | race_code | char(3) | Race code |
| 28 | ethnic_code | char(3) | Ethnicity code |
| 29 | party_cd | char(3) | Registered party code (REP, DEM, UNA, etc.) |
| 30 | gender_code | char(1) | Gender/sex code |
| 31 | birth_year | char(4) | Year of birth |
| 32 | age_at_year_end | char(3) | Age at end of year |
| 33 | birth_state | varchar(2) | Birth state |
| 34 | drivers_lic | char(1) | Has driver's license (Y/N) |
| 35 | precinct_abbrv | varchar(6) | Precinct abbreviation |
| 36 | precinct_desc | varchar(60) | Precinct name |
| 37 | municipality_abbrv | varchar(6) | Municipality abbreviation |
| 38 | municipality_desc | varchar(60) | Municipality name |
| 39 | ward_abbrv | varchar(6) | Ward abbreviation |
| 40 | ward_desc | varchar(60) | Ward name |
| 41 | cong_dist_abbrv | varchar(6) | Congressional district |
| 42 | super_court_abbrv | varchar(6) | Superior court district |
| 43 | judic_dist_abbrv | varchar(6) | Judicial district |
| 44 | nc_senate_abbrv | varchar(6) | NC Senate district |
| 45 | nc_house_abbrv | varchar(6) | NC House district |
| 46 | county_commis_abbrv | varchar(6) | County commissioner district |
| 47 | county_commis_desc | varchar(60) | County commissioner name |
| 48 | township_abbrv | varchar(6) | Township abbreviation |
| 49 | township_desc | varchar(60) | Township name |
| 50 | school_dist_abbrv | varchar(6) | School district abbreviation |
| 51 | school_dist_desc | varchar(60) | School district name |
| 52 | fire_dist_abbrv | varchar(6) | Fire district abbreviation |
| 53 | fire_dist_desc | varchar(60) | Fire district name |
| 54 | water_dist_abbrv | varchar(6) | Water district abbreviation |
| 55 | water_dist_desc | varchar(60) | Water district name |
| 56 | sewer_dist_abbrv | varchar(6) | Sewer district abbreviation |
| 57 | sewer_dist_desc | varchar(60) | Sewer district name |
| 58 | sanit_dist_abbrv | varchar(6) | Sanitation district abbreviation |
| 59 | sanit_dist_desc | varchar(60) | Sanitation district name |
| 60 | rescue_dist_abbrv | varchar(6) | Rescue district abbreviation |
| 61 | rescue_dist_desc | varchar(60) | Rescue district name |
| 62 | munic_dist_abbrv | varchar(6) | Municipal district abbreviation |
| 63 | munic_dist_desc | varchar(60) | Municipal district name |
| 64 | dist_1_abbrv | varchar(6) | Prosecutorial district abbreviation |
| 65 | dist_1_desc | varchar(60) | Prosecutorial district name |
| 66 | vtd_abbrv | varchar(6) | Voter tabulation district abbreviation |
| 67 | vtd_desc | varchar(60) | Voter tabulation district name |

---

## Key join

- **nc_datatrust.statevoterid** = **nc_voters.ncid** (primary identity join for Pass 1; Master Plan §0.1).

---

## Status codes (status_cd)

| Code | Description |
|------|-------------|
| A | ACTIVE |
| D | DENIED |
| I | INACTIVE |
| R | REMOVED |
| S | TEMPORARY (Military/Overseas) |

## Party codes (party_cd)

Common: REP, DEM, UNA, LIB, GRE.
