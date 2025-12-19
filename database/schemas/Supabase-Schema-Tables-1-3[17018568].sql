# Supabase Database Schema for 860-Field Donor Profiling System
## Complete SQL CREATE TABLE Statements for BroyhillGOP Conservative Donor Intelligence

**PostgreSQL/Supabase-Optimized Multi-Table Architecture**

---

## ARCHITECTURE OVERVIEW

To avoid PostgreSQL's column limits and optimize query performance, the 860 fields are split across **7 linked tables**:

1. **donors_core** (120 fields) - Primary table with most-used fields
2. **donors_extended_demographic** (100 fields) - Extended demographic data
3. **donors_professional_financial** (140 fields) - Career, wealth, business data
4. **donors_lifestyle_interests** (150 fields) - Hobbies, media, consumer behavior
5. **donors_health_psychological** (110 fields) - Health, personality, values
6. **donors_political_engagement** (125 fields) - Political activity, giving history
7. **donors_religious_civic** (115 fields) - Faith, community involvement

**All tables linked by `donor_id` UUID primary/foreign key**

---

## TABLE 1: donors_core (120 FIELDS)

**Most frequently accessed fields - Primary donor table**

```sql
-- Drop existing table if needed
DROP TABLE IF EXISTS donors_core CASCADE;

-- Create core donor table
CREATE TABLE donors_core (
  -- PRIMARY KEY
  donor_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  
  -- BASIC IDENTITY (15 fields)
  first_name TEXT,
  last_name TEXT,
  full_name TEXT,
  middle_name TEXT,
  suffix TEXT, -- Jr, Sr, III, etc.
  gender TEXT CHECK (gender IN ('Male', 'Female', 'Prefer not to say')),
  gender_donor_profile TEXT CHECK (gender_donor_profile IN ('Male-typical', 'Female-typical', 'Mixed')),
  age INTEGER,
  age_range TEXT CHECK (age_range IN ('<30', '30-39', '40-49', '50-59', '60-69', '70-79', '80+')),
  birth_year INTEGER,
  birth_date DATE,
  generation TEXT CHECK (generation IN ('Gen Z', 'Millennial', 'Gen X', 'Baby Boomer', 'Silent Generation', 'Greatest Generation')),
  ethnicity TEXT,
  primary_language TEXT DEFAULT 'English',
  citizenship_status TEXT CHECK (citizenship_status IN ('Natural born', 'Naturalized', 'Permanent resident')),
  
  -- CONTACT INFORMATION (10 fields)
  email TEXT,
  email_verified BOOLEAN DEFAULT FALSE,
  email_bounced BOOLEAN DEFAULT FALSE,
  cell_phone TEXT,
  home_phone TEXT,
  work_phone TEXT,
  preferred_contact_method TEXT CHECK (preferred_contact_method IN ('Email', 'Cell', 'Home phone', 'Mail', 'Text')),
  do_not_contact BOOLEAN DEFAULT FALSE,
  do_not_call BOOLEAN DEFAULT FALSE,
  do_not_email BOOLEAN DEFAULT FALSE,
  
  -- PHYSICAL ADDRESS (10 fields)
  mailing_address TEXT,
  street_number TEXT,
  street_name TEXT,
  apartment_unit TEXT,
  city TEXT,
  county TEXT,
  state TEXT DEFAULT 'NC',
  zip TEXT,
  zip_plus_4 TEXT,
  congressional_district INTEGER,
  
  -- GEOGRAPHIC PROFILE (10 fields)
  years_at_current_address INTEGER,
  years_in_nc INTEGER,
  nc_native BOOLEAN DEFAULT FALSE,
  birth_state TEXT,
  birth_country TEXT DEFAULT 'USA',
  urban_suburban_rural TEXT CHECK (urban_suburban_rural IN ('Urban', 'Suburban', 'Rural')),
  precinct_number TEXT,
  voting_district TEXT,
  school_district TEXT,
  geographic_mobility TEXT CHECK (geographic_mobility IN ('Very mobile', 'Moderate', 'Rooted')),
  
  -- FAMILY & HOUSEHOLD (15 fields)
  marital_status TEXT CHECK (marital_status IN ('Single', 'Married', 'Divorced', 'Widowed', 'Separated', 'Domestic Partnership')),
  spouse_name TEXT,
  spouse_donor_id UUID REFERENCES donors_core(donor_id),
  children_count INTEGER DEFAULT 0,
  children_ages TEXT, -- Comma-separated list
  grandchildren_count INTEGER DEFAULT 0,
  family_size INTEGER, -- Total household members
  household_size INTEGER, -- People living in home
  household_composition TEXT,
  multigenerational_household BOOLEAN DEFAULT FALSE,
  primary_caregiver BOOLEAN DEFAULT FALSE,
  stay_at_home_parent BOOLEAN DEFAULT FALSE,
  single_parent BOOLEAN DEFAULT FALSE,
  empty_nester BOOLEAN DEFAULT FALSE,
  family_structure_stability TEXT,
  
  -- OCCUPATION & EMPLOYMENT (15 fields)
  employment_status TEXT CHECK (employment_status IN ('Employed full-time', 'Part-time', 'Self-employed', 'Business owner', 'Retired', 'Unemployed', 'Student')),
  occupation_title TEXT,
  occupation_category TEXT,
  occupation_subcategory TEXT,
  employer_name TEXT,
  employer_type TEXT,
  employer_size TEXT,
  years_with_current_employer INTEGER,
  retired BOOLEAN DEFAULT FALSE,
  retirement_year INTEGER,
  pre_retirement_occupation TEXT,
  business_owner BOOLEAN DEFAULT FALSE,
  business_name TEXT,
  business_type TEXT,
  professional_license TEXT,
  
  -- EDUCATION (10 fields)
  highest_degree TEXT CHECK (highest_degree IN ('High school', 'Associate', 'Bachelor''s', 'Master''s', 'PhD', 'MD', 'JD', 'MBA', 'Other professional')),
  undergraduate_university TEXT,
  undergraduate_major TEXT,
  undergraduate_graduation_year INTEGER,
  graduate_degree_type TEXT,
  graduate_university TEXT,
  graduate_field TEXT,
  conservative_university BOOLEAN DEFAULT FALSE,
  high_school_name TEXT,
  high_school_type TEXT,
  
  -- POLITICAL BASICS (15 fields)
  registered_voter BOOLEAN DEFAULT FALSE,
  voter_registration_party TEXT CHECK (voter_registration_party IN ('Republican', 'Unaffiliated', 'Democrat', 'Libertarian', 'Other')),
  political_ideology TEXT CHECK (political_ideology IN ('Very conservative', 'Conservative', 'Moderate conservative', 'Moderate', 'Liberal', 'Very liberal')),
  voter_consistency_score INTEGER CHECK (voter_consistency_score BETWEEN 0 AND 100),
  primary_election_voter BOOLEAN DEFAULT FALSE,
  political_party_registration TEXT,
  trump_support_level TEXT CHECK (trump_support_level IN ('Strong supporter', 'Moderate supporter', 'Neutral', 'Opposed', 'Strongly opposed')),
  maga_movement_alignment TEXT,
  tea_party_alignment TEXT,
  fiscal_conservatism_level TEXT,
  social_conservatism_level TEXT,
  libertarian_tendencies TEXT,
  populist_tendencies TEXT,
  single_issue_voter BOOLEAN DEFAULT FALSE,
  single_issue_if_yes TEXT,
  
  -- DONATION HISTORY (20 fields)
  total_lifetime_donations NUMERIC(10,2) DEFAULT 0,
  total_donations_10yr NUMERIC(10,2) DEFAULT 0,
  total_donations_5yr NUMERIC(10,2) DEFAULT 0,
  total_donations_2yr NUMERIC(10,2) DEFAULT 0,
  avg_donation_amount NUMERIC(10,2) DEFAULT 0,
  largest_donation NUMERIC(10,2) DEFAULT 0,
  smallest_donation NUMERIC(10,2) DEFAULT 0,
  donation_frequency INTEGER DEFAULT 0,
  first_donation_date DATE,
  last_donation_date DATE,
  recurring_donor BOOLEAN DEFAULT FALSE,
  recurring_amount_monthly NUMERIC(10,2),
  winred_total NUMERIC(10,2) DEFAULT 0,
  anedot_total NUMERIC(10,2) DEFAULT 0,
  fec_itemized_total NUMERIC(10,2) DEFAULT 0,
  primary_candidate_supported TEXT,
  donation_pattern TEXT,
  donation_growth_trajectory TEXT CHECK (donation_growth_trajectory IN ('Increasing', 'Stable', 'Decreasing')),
  years_as_political_donor INTEGER,
  donation_consistency_score INTEGER CHECK (donation_consistency_score BETWEEN 0 AND 100),
  
  -- TIER & SCORING (10 fields)
  tier INTEGER CHECK (tier BETWEEN 1 AND 4) DEFAULT 4,
  propensity_score INTEGER CHECK (propensity_score BETWEEN 0 AND 100) DEFAULT 0,
  capacity_score INTEGER CHECK (capacity_score BETWEEN 0 AND 100) DEFAULT 0,
  engagement_score INTEGER CHECK (engagement_score BETWEEN 0 AND 100) DEFAULT 0,
  religious_score INTEGER CHECK (religious_score BETWEEN 0 AND 100) DEFAULT 0,
  conservative_alignment_score INTEGER CHECK (conservative_alignment_score BETWEEN 0 AND 100) DEFAULT 0,
  issue_priority_1 TEXT,
  issue_priority_2 TEXT,
  issue_priority_3 TEXT,
  composite_donor_score INTEGER CHECK (composite_donor_score BETWEEN 0 AND 100) DEFAULT 0,
  
  -- METADATA (10 fields)
  data_source TEXT,
  last_enriched TIMESTAMPTZ,
  bettercontact_confidence INTEGER,
  datagma_enriched BOOLEAN DEFAULT FALSE,
  donorsearch_enriched BOOLEAN DEFAULT FALSE,
  wealthengine_enriched BOOLEAN DEFAULT FALSE,
  fec_sync_date TIMESTAMPTZ,
  winred_sync_date TIMESTAMPTZ,
  anedot_sync_date TIMESTAMPTZ,
  last_updated TIMESTAMPTZ DEFAULT NOW(),
  
  -- SYSTEM FIELDS
  created_at TIMESTAMPTZ DEFAULT NOW(),
  created_by TEXT,
  notes TEXT
);

-- Create indexes for performance
CREATE INDEX idx_donors_last_name ON donors_core(last_name);
CREATE INDEX idx_donors_email ON donors_core(email);
CREATE INDEX idx_donors_zip ON donors_core(zip);
CREATE INDEX idx_donors_tier ON donors_core(tier);
CREATE INDEX idx_donors_propensity_score ON donors_core(propensity_score DESC);
CREATE INDEX idx_donors_total_donations ON donors_core(total_lifetime_donations DESC);
CREATE INDEX idx_donors_state ON donors_core(state);
CREATE INDEX idx_donors_city ON donors_core(city, state);
CREATE INDEX idx_donors_conservative_score ON donors_core(conservative_alignment_score DESC);

-- Enable Row Level Security
ALTER TABLE donors_core ENABLE ROW LEVEL SECURITY;
```

---

## TABLE 2: donors_extended_demographic (100 FIELDS)

**Extended demographic, family, and generational data**

```sql
DROP TABLE IF EXISTS donors_extended_demographic CASCADE;

CREATE TABLE donors_extended_demographic (
  profile_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  donor_id UUID NOT NULL REFERENCES donors_core(donor_id) ON DELETE CASCADE,
  
  -- EXTENDED IDENTITY (15 fields)
  immigrant_generation TEXT CHECK (immigrant_generation IN ('1st gen', '2nd gen', '3rd+ gen')),
  bilingual BOOLEAN DEFAULT FALSE,
  languages_spoken TEXT, -- Comma-separated
  accent_indicator TEXT,
  cultural_identity TEXT,
  ethnic_heritage TEXT,
  religious_ethnicity_match BOOLEAN, -- e.g., Jewish ethnicity + Jewish religion
  name_origin_indicator TEXT, -- Irish, Italian, German, etc.
  maiden_name TEXT,
  previous_names TEXT,
  nickname TEXT,
  goes_by_name TEXT,
  title_prefix TEXT, -- Dr., Rev., Col., etc.
  professional_designations TEXT, -- CPA, MD, PE, etc.
  honorific_suffix TEXT,
  
  -- FAMILY DEEP DIVE (25 fields)
  years_married INTEGER,
  marriage_count INTEGER DEFAULT 0,
  spouse_political_alignment TEXT CHECK (spouse_political_alignment IN ('Both conservative', 'Mixed household', 'Unknown')),
  children_gender_breakdown TEXT, -- e.g., "2 sons, 1 daughter"
  great_grandchildren_count INTEGER DEFAULT 0,
  family_size_extended INTEGER, -- Including extended family
  working_parent_dual_income BOOLEAN,
  adult_children_living_home BOOLEAN DEFAULT FALSE,
  eldercare_responsibility BOOLEAN DEFAULT FALSE,
  adoption_or_foster BOOLEAN DEFAULT FALSE,
  blended_family BOOLEAN DEFAULT FALSE,
  step_children_count INTEGER DEFAULT 0,
  children_in_private_school BOOLEAN DEFAULT FALSE,
  children_in_christian_school BOOLEAN DEFAULT FALSE,
  children_homeschooled BOOLEAN DEFAULT FALSE,
  children_school_type TEXT,
  family_political_discussions_frequency TEXT,
  family_attends_church_together BOOLEAN,
  family_vacations_together BOOLEAN,
  family_traditions_strength TEXT CHECK (family_traditions_strength IN ('Very strong', 'Strong', 'Moderate', 'Weak')),
  family_cohesion_level TEXT,
  extended_family_proximity TEXT CHECK (extended_family_proximity IN ('Same city', 'Same state', 'Different state', 'Distant')),
  grandparent_involved BOOLEAN DEFAULT FALSE,
  godparent_role BOOLEAN DEFAULT FALSE,
  legal_guardian_for_others BOOLEAN DEFAULT FALSE,
  
  -- GENERATIONAL WEALTH & BACKGROUND (20 fields)
  grew_up_economic_class TEXT CHECK (grew_up_economic_class IN ('Working class', 'Middle class', 'Upper-middle', 'Wealthy')),
  economic_mobility TEXT CHECK (economic_mobility IN ('Upwardly mobile', 'Maintained status', 'Downwardly mobile')),
  first_generation_wealth BOOLEAN DEFAULT FALSE,
  inherited_wealth BOOLEAN DEFAULT FALSE,
  inheritance_amount_range TEXT,
  family_business_inherited BOOLEAN DEFAULT FALSE,
  trust_fund_beneficiary BOOLEAN DEFAULT FALSE,
  generational_wealth_transfer_pending BOOLEAN DEFAULT FALSE,
  estate_planning_status TEXT,
  charitable_giving_family_history BOOLEAN,
  political_giving_family_history BOOLEAN,
  family_political_legacy BOOLEAN,
  parents_political_affiliation TEXT,
  parents_religious_background TEXT,
  parents_education_level TEXT,
  parents_occupation_class TEXT,
  siblings_count INTEGER DEFAULT 0,
  birth_order TEXT CHECK (birth_order IN ('Oldest', 'Middle', 'Youngest', 'Only child', 'Twin')),
  sibling_political_alignment TEXT,
  family_military_tradition BOOLEAN,
  
  -- HOUSEHOLD CHARACTERISTICS (15 fields)
  household_income_bracket TEXT,
  household_income_sources TEXT, -- Comma-separated
  dual_income_household BOOLEAN,
  primary_breadwinner_gender TEXT CHECK (primary_breadwinner_gender IN ('Male', 'Female', 'Equal')),
  household_budget_discretionary_income NUMERIC(10,2),
  household_debt_level TEXT CHECK (household_debt_level IN ('No debt', 'Low', 'Moderate', 'High', 'Very high')),
  household_savings_rate TEXT,
  household_pets TEXT, -- "2 dogs, 1 cat"
  household_pet_count INTEGER DEFAULT 0,
  household_lifestyle TEXT,
  household_organization TEXT,
  household_values_emphasis TEXT,
  homeowner_vs_renter TEXT CHECK (homeowner_vs_renter IN ('Own outright', 'Mortgage', 'Rent', 'Live with family')),
  home_value NUMERIC(12,2),
  home_mortgage_balance NUMERIC(12,2),
  
  -- RESIDENTIAL HISTORY (10 fields)
  housing_stability_score INTEGER CHECK (housing_stability_score BETWEEN 0 AND 100),
  previous_states_lived TEXT, -- Comma-separated
  urban_suburban_rural_upbringing TEXT,
  hometown_city TEXT,
  hometown_state TEXT,
  snowbird_status BOOLEAN DEFAULT FALSE,
  snowbird_destination TEXT,
  second_home_location TEXT,
  second_home_value NUMERIC(12,2),
  planning_to_relocate BOOLEAN DEFAULT FALSE,
  
  -- LIFE STAGE & STATUS (15 fields)
  life_stage TEXT CHECK (life_stage IN ('Young professional', 'Young family', 'Established family', 'Empty nester', 'Retired', 'Elderly')),
  career_stage TEXT,
  parenting_stage TEXT,
  retirement_status TEXT,
  health_status_general TEXT,
  disability_status TEXT,
  mobility_limitations TEXT,
  hearing_impairment BOOLEAN,
  vision_impairment BOOLEAN,
  cognitive_status TEXT,
  caregiver_status TEXT,
  widowhood_years INTEGER,
  divorce_recovery_stage TEXT,
  major_life_transition_recent BOOLEAN,
  life_satisfaction_indicator TEXT,
  
  -- METADATA
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_updated TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_extended_donor_id ON donors_extended_demographic(donor_id);
CREATE INDEX idx_extended_economic_mobility ON donors_extended_demographic(economic_mobility);
CREATE INDEX idx_extended_life_stage ON donors_extended_demographic(life_stage);

ALTER TABLE donors_extended_demographic ENABLE ROW LEVEL SECURITY;
```

---

## TABLE 3: donors_professional_financial (140 FIELDS)

**Career, business ownership, wealth, financial sophistication**

```sql
DROP TABLE IF EXISTS donors_professional_financial CASCADE;

CREATE TABLE donors_professional_financial (
  profile_id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
  donor_id UUID NOT NULL REFERENCES donors_core(donor_id) ON DELETE CASCADE,
  
  -- OCCUPATION DETAILS (25 fields)
  occupation_category_primary TEXT,
  medical_specialty TEXT,
  engineering_specialty TEXT,
  legal_specialty TEXT,
  agriculture_type TEXT,
  agriculture_acres INTEGER,
  business_sector TEXT,
  employer_industry TEXT,
  employer_political_culture TEXT,
  years_in_current_occupation INTEGER,
  career_trajectory TEXT,
  job_satisfaction_indicators TEXT,
  remote_work_status TEXT,
  work_schedule_flexibility TEXT,
  travel_for_work_frequency TEXT,
  work_stress_level TEXT,
  work_life_balance TEXT,
  union_membership BOOLEAN DEFAULT FALSE,
  union_political_alignment TEXT,
  professional_liability_insurance BOOLEAN,
  professional_reputation TEXT,
  board_certified BOOLEAN,
  regulatory_oversight_level TEXT,
  professional_autonomy TEXT,
  income_stability TEXT,
  
  -- COMPENSATION & BENEFITS (15 fields)
  compensation_structure TEXT,
  salary_range TEXT,
  bonus_eligible BOOLEAN,
  commission_based BOOLEAN,
  stock_options_rsus BOOLEAN,
  pension_benefit BOOLEAN,
  401k_employer_match BOOLEAN,
  401k_contribution_rate TEXT,
  401k_balance TEXT,
  health_insurance_quality TEXT,
  paid_time_off_days INTEGER,
  flexible_spending_account BOOLEAN,
  professional_development_budget BOOLEAN,
  company_car BOOLEAN,
  executive_perks BOOLEAN,
  
  -- BUSINESS OWNERSHIP DETAILS (30 fields)
  business_ownership_percentage INTEGER,
  business_founded_or_acquired TEXT,
  year_business_founded INTEGER,
  years_business_operating INTEGER,
  business_revenue_range TEXT,
  business_revenue_annual NUMERIC(12,2),
  business_profit_margin TEXT,
  business_employee_count INTEGER,
  business_growth_stage TEXT,
  business_exit_strategy TEXT,
  business_debt_level TEXT,
  business_real_estate_owned BOOLEAN,
  franchise_owner BOOLEAN,
  franchise_brand TEXT,
  multi_location_business BOOLEAN,
  number_of_locations INTEGER,
  seasonal_business BOOLEAN,
  b2b_vs_b2c TEXT,
  government_contracts BOOLEAN,
  government_contract_value_annual NUMERIC(12,2),
  chamber_commerce_member BOOLEAN,
  business_awards_recognition TEXT,
  sba_loans BOOLEAN,
  minority_owned_business BOOLEAN,
  woman_owned_business BOOLEAN,
  veteran_owned_business BOOLEAN,
  family_business BOOLEAN,
  succession_plan BOOLEAN,
  business_insurance_coverage TEXT,
  business_litigation_history BOOLEAN,
  
  -- PROFESSIONAL NETWORKS (20 fields)
  industry_associations TEXT, -- Comma-separated list
  association_leadership_roles TEXT,
  professional_conferences_annual INTEGER,
  networking_activity_level TEXT,
  linkedin_connections_count INTEGER,
  linkedin_activity_level TEXT,
  professional_referral_network_strength TEXT,
  mentor_to_professionals BOOLEAN,
  industry_thought_leader BOOLEAN,
  speaking_engagements_annual INTEGER,
  published_work_professional BOOLEAN,
  publications_count INTEGER,
  patents_held INTEGER,
  awards_professional TEXT, -- List of awards
  board_seats_corporate INTEGER DEFAULT 0,
  board_seats_nonprofit INTEGER DEFAULT 0,
  advisory_board_positions INTEGER DEFAULT 0,
  consulting_side_income BOOLEAN,
  consulting_rate_hourly NUMERIC(10,2),
  professional_mentor_has BOOLEAN,
  
  -- WEALTH COMPOSITION (25 fields)
  estimated_net_worth TEXT,
  estimated_net_worth_numeric NUMERIC(12,2),
  liquid_net_worth NUMERIC(12,2),
  illiquid_net_worth NUMERIC(12,2),
  primary_wealth_source TEXT,
  wealth_building_phase TEXT,
  investment_real_estate_count INTEGER DEFAULT 0,
  investment_real_estate_value NUMERIC(12,2),
  rental_income_annual NUMERIC(12,2),
  commercial_real_estate BOOLEAN,
  farmland_acres INTEGER,
  timberland_acres INTEGER,
  mineral_rights BOOLEAN,
  vacation_home_value NUMERIC(12,2),
  vehicle_count INTEGER,
  luxury_vehicle BOOLEAN,
  boat_ownership BOOLEAN,
  boat_value NUMERIC(10,2),
  aircraft_ownership BOOLEAN,
  rv_ownership BOOLEAN,
  collectibles_value NUMERIC(10,2),
  precious_metals_holdings NUMERIC(10,2),
  cryptocurrency_holdings NUMERIC(10,2),
  stock_portfolio_value NUMERIC(12,2),
  private_equity_investments BOOLEAN,
  
  -- FINANCIAL SOPHISTICATION (25 fields)
  financial_literacy_level TEXT,
  financial_advisor_usage BOOLEAN,
  financial_advisor_firm TEXT,
  investment_strategy TEXT,
  risk_tolerance TEXT,
  portfolio_diversification TEXT,
  ira_accounts TEXT, -- Types of IRAs
  ira_max_contributor BOOLEAN,
  hsa_max_contributor BOOLEAN,
  hsa_balance NUMERIC(10,2),
  529_college_savings BOOLEAN,
  529_balance NUMERIC(10,2),
  taxable_brokerage_account BOOLEAN,
  dividend_income_annual NUMERIC(10,2),
  capital_gains_annual NUMERIC(10,2),
  tax_bracket TEXT,
  tax_planning_sophistication TEXT,
  estate_tax_exposure BOOLEAN,
  trust_structures TEXT, -- Types of trusts
  life_insurance_coverage TEXT,
  life_insurance_cash_value NUMERIC(10,2),
  disability_insurance BOOLEAN,
  long_term_care_insurance BOOLEAN,
  umbrella_insurance_amount NUMERIC(10,2),
  credit_score_range TEXT,
  
  -- METADATA
  created_at TIMESTAMPTZ DEFAULT NOW(),
  last_updated TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_professional_donor_id ON donors_professional_financial(donor_id);
CREATE INDEX idx_professional_net_worth ON donors_professional_financial(estimated_net_worth_numeric DESC);
CREATE INDEX idx_professional_business_owner ON donors_professional_financial(business_owner);
CREATE INDEX idx_professional_occupation ON donors_professional_financial(occupation_category_primary);

ALTER TABLE donors_professional_financial ENABLE ROW LEVEL SECURITY;
```

---

*[Due to response length limits, I'm providing the first 3 tables. Would you like me to continue with Tables 4-7 in a second file?]*

**Tables 4-7 Still To Create:**
- Table 4: donors_lifestyle_interests (150 fields) - Hobbies, media, consumer behavior
- Table 5: donors_health_psychological (110 fields) - Health, personality, values  
- Table 6: donors_political_engagement (125 fields) - Political activity, giving patterns
- Table 7: donors_religious_civic (115 fields) - Faith, community involvement

**Should I create the remaining 4 tables now?**
