# NCBOE Pipeline — Schema Reference

Generated from `information_schema.columns` for key tables.

---

## public.nc_boe_donations_raw

id (bigint, NOT NULL), donor_name (character varying), street_line_1 (character varying), street_line_2 (character varying), city (character varying), state (character varying), zip_code (character varying), profession_job_title (character varying), employer_name (character varying), transaction_type (character varying), committee_name (character varying), committee_sboe_id (character varying), committee_street_1 (character varying), committee_street_2 (character varying), committee_city (character varying), committee_state (character varying), committee_zip_code (character varying), report_name (character varying), date_occured_raw (character varying), account_code (character varying), amount_raw (character varying), form_of_payment (character varying), purpose (character varying), candidate_referendum_name (character varying), declaration (character varying), source_file (character varying), loaded_at (timestamp with time zone), norm_last (character varying), norm_first (character varying), norm_addr (character varying), norm_zip5 (character varying), norm_city (character varying), norm_state (character varying), amount_numeric (numeric), date_occurred (date), canonical_first (character varying), committee_type (character varying), content_hash (text), dedup_key (text), voter_ncid (text), zip9 (text), voter_party_cd (text), employer_normalized (text), middle_name (text), name_suffix (text), norm_zip9 (text), fec_contributor_id (text), source_cycle (text), rncid (text), cell_phone (text), email (text), birth_year (integer), member_id (uuid), parsed_last (text), parsed_first (text), parsed_middle (text), parsed_suffix (text), parsed_nickname (text), is_organization (boolean)

---

## public.donation_transactions

id (uuid, NOT NULL), person_id (uuid), person_match_key (character varying), transaction_id (character varying), amount (numeric, NOT NULL), transaction_date (date, NOT NULL), transaction_quarter (character varying), transaction_year (integer), recipient_type (character varying), recipient_name (character varying), office_level (character varying), data_source (character varying), created_at (timestamp with time zone)

---

## nc_data_committee.donors

id (uuid, NOT NULL), first_name (character varying), middle_name (character varying), last_name (character varying), suffix (character varying), nickname (character varying), email_primary (character varying), email_secondary (character varying), email_status (character varying), phone_mobile (character varying), phone_home (character varying), phone_work (character varying), phone_status (character varying), address_line1 (character varying), address_line2 (character varying), city (character varying), state (character varying), zip (character varying), zip_plus4 (character varying), county (character varying), address_status (character varying), date_of_birth (date), gender (character varying), employer (character varying), occupation (character varying), job_title (character varying), industry (character varying), estimated_wealth (numeric), home_value (numeric), is_business_owner (boolean), net_worth_range (character varying), party_registration (character varying), voter_id (character varying), congressional_district (character varying), state_senate_district (character varying), state_house_district (character varying), precinct (character varying), lead_score (integer), grade (character varying), score_components (jsonb), scored_at (timestamp with time zone), primary_faction (character varying), secondary_faction (character varying), faction_scores (jsonb), faction_confidence (numeric), lifetime_giving (numeric), donation_count (integer), first_donation_date (date), last_donation_date (date), last_donation_amount (numeric), average_donation_amount (numeric), largest_donation_amount (numeric), email_open_rate (numeric), email_click_rate (numeric), last_contact_date (date), last_contact_channel (character varying), contact_count (integer), do_not_email (boolean), do_not_call (boolean), do_not_mail (boolean), do_not_sms (boolean), do_not_contact (boolean), is_deceased (boolean), enriched_at (timestamp with time zone), verified_at (timestamp with time zone), linkedin_url (character varying), source (character varying), source_date (date), tags (jsonb), issues (jsonb), notes (text), created_at (timestamp with time zone), updated_at (timestamp with time zone)

---

## public.donations

donation_id (uuid, NOT NULL), donor_id (uuid, NOT NULL), candidate_id (uuid), campaign_id (uuid), amount (numeric, NOT NULL), currency (character varying), fee_amount (numeric), net_amount (numeric), payment_method (character varying, NOT NULL), payment_gateway (character varying), gateway_transaction_id (character varying), gateway_customer_id (character varying), last_four (character varying), card_brand (character varying), status (character varying), status_message (text), election_type (character varying), election_year (integer), race_level (character varying), is_itemized (boolean), fec_reported (boolean), fec_report_id (character varying), donor_name (character varying), donor_address (text), donor_city (character varying), donor_state (character varying), donor_zip (character varying), donor_employer (character varying), donor_occupation (character varying), is_recurring (boolean), recurring_id (uuid), refunded_amount (numeric), refund_reason (text), refund_date (timestamp without time zone), source (character varying), utm_source (character varying), utm_campaign (character varying), device_type (character varying), ip_address (character varying), donation_date (timestamp without time zone), processed_at (timestamp without time zone), created_at (timestamp without time zone), updated_at (timestamp without time zone)

---

## public.person_master

person_id (uuid, NOT NULL), first_name (text), middle_name (text), last_name (text), suffix (text), sex (text), birth_year (text), age (text), cell (text), landline (text), email (text), street (text), city (text), state (text), zip5 (text), county (text), registered_party (text), voter_status (text), congressional_district (text), state_senate_district (text), state_house_district (text), precinct (text), republican_party_score (text), turnout_score (text), datatrust_rncid (text), ncvoter_ncid (text), rnc_rncid (text), boe_donor_id (text), fec_contributor_id (text), is_voter (boolean), is_donor (boolean), is_volunteer (boolean), source_count (integer), created_at (timestamp with time zone), updated_at (timestamp with time zone), golden_record_id (integer), person_match_key (text)

---

## Key Relationships

- `donation_transactions.transaction_id` = `NCBOE-{nc_boe_donations_raw.id}`
- `donation_transactions.person_match_key` = `LOWER(norm_last || '|' || canonical_first || '|' || norm_zip5)`
- `public.donations.donor_id` → `nc_data_committee.donors.id`
- `person_master.person_id` = PK (not `id`)
