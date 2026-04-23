-- 103_user_view_affixed_committee_names.sql
-- Purpose: Ensure user-facing committee donor view renders full committee names.
-- Depends on: 102_committee_name_affix_map.sql (committee.affix_committee_name)

CREATE OR REPLACE VIEW committee.v_party_committee_individual_donors AS
SELECT
    p.id,
    p.source_file,
    p.name,
    p.street_line_1,
    p.street_line_2,
    p.city,
    p.state,
    p.zip_code,
    p.profession_job_title,
    p.employer_name,
    p.transaction_type,
    committee.affix_committee_name(p.committee_name) AS committee_name,
    p.committee_sboe_id,
    p.committee_street_1,
    p.committee_street_2,
    p.committee_city,
    p.committee_state,
    p.committee_zip_code,
    p.report_name,
    p.date_occured,
    p.account_code,
    p.amount,
    p.form_of_payment,
    p.purpose,
    p.candidate_referendum_name,
    p.declaration,
    p.norm_last,
    p.norm_first,
    p.norm_middle,
    p.norm_suffix,
    p.norm_prefix,
    p.norm_zip5,
    p.norm_amount,
    p.norm_date,
    p.address_numbers,
    p.is_aggregated,
    p.cluster_id,
    p.created_at,
    p.norm_last_core,
    p.norm_first_core,
    p.norm_middle_initial,
    p.addr_numeric_tokens,
    p.identity_block_key,
    p.identity_key_loose,
    p.identity_anomaly_short_last,
    p.identity_norm_version
FROM staging.ncboe_party_committee_donations p
WHERE p.transaction_type = 'Individual'
  AND COALESCE(p.is_aggregated, false) = false
  AND upper(COALESCE(p.name, '')) NOT LIKE '%AGGREGAT%'
  AND NOT (
    p.name ~* '\mPAC\M'
    OR p.name ~* '\mLLC\M'
    OR p.name ~* '\mL\.L\.C\M'
    OR p.name ~* '\mLLP\M'
    OR p.name ~* '\mINC\M'
    OR p.name ~* '\mCORP\M'
    OR p.name ~* '\mCORPORATION\M'
    OR p.name ~* '\mCOMMITTEE\M'
    OR p.name ~* '\mFOUNDATION\M'
    OR p.name ~* '\mFEDERATION\M'
    OR p.name ~* '\mTRUST\M'
    OR p.name ~* '\mHOLDINGS\M'
    OR p.name ~* '\mPARTNERSHIP\M'
    OR p.name ~* '\mASSOCIATION\M'
    OR p.name ~* '\mGUILD\M'
    OR p.name ~* 'CAMPAIGN[[:space:]]+FUND'
    OR p.name ~* '\mPOLITICAL\M'
  )
  AND upper(COALESCE(p.norm_last, '')) <> ALL (
    ARRAY[
      'PAC',
      'LLC',
      'INC',
      'CORP',
      'CORPORATION',
      'COMMITTEE',
      'FUND',
      'TRUST',
      'FOUNDATION',
      'FEDERATION',
      'GROUP',
      'HOLDINGS',
      'ASSOCIATION',
      'GUILD',
      'COMPANY',
      'PARTNERSHIP',
      'CONTRIBUTION',
      'INDIVIDUAL'
    ]
  )
  AND upper(COALESCE(p.norm_first, '')) <> ALL (
    ARRAY['AGGREGATED', 'PAC', 'LLC', 'COMMITTEE']
  );
