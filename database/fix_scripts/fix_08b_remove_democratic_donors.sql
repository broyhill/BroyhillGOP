-- =============================================================================
-- FIX 08b: Remove Democratic-only donors from contacts
-- Problem: v_individual_donations had no party filter — D donors entered contacts
-- Project: BroyhillGOP-Claude | isbgjpnbocdkeslofota
-- Date: 2026-03-29
-- =============================================================================
-- DESIGN INTENT: contacts contains only donors who gave to Republican or PAC
-- committees. Donors who ONLY gave to Democratic committees must be removed.
-- Donors who gave to BOTH R and D committees stay — their R giving is valid.
-- UNKNOWN donors stay — they may be Republican, just unclassified.
-- =============================================================================
-- DO NOT RUN AS SINGLE BATCH. Steps in order, validate after each.
-- Requires "I authorize this action" from Ed before Step 3 (DELETE).
-- =============================================================================

-- -----------------------------------------------------------------------
-- STEP 1: Fix v_individual_donations — add Republican-only filter
-- -----------------------------------------------------------------------

CREATE OR REPLACE VIEW v_individual_donations AS
SELECT fd.*
FROM fec_donations fd
JOIN core.contribution_map cm
    ON cm.source_id = fd.id
    AND cm.source_system = 'fec_donations'
WHERE fd.receipt_type IN ('15', '15E', '15J')
  AND cm.party_flag IN ('R', 'PAC', 'UNKNOWN');
-- Excludes party_flag = 'D' and 'OTHER'

-- Validate: should drop from 2,388,256 to ~1,240,793
SELECT COUNT(*) AS new_view_count FROM v_individual_donations;
-- Expected: ~1,240,793 (R + PAC + UNKNOWN only)

-- -----------------------------------------------------------------------
-- STEP 2: Identify contacts that came from D-only FEC source records
-- These are contacts whose ONLY person_source_links entries
-- trace back to Democratic committee donations
-- -----------------------------------------------------------------------

-- Find contact_ids that should be removed:
-- Came from FEC source (Steps 3 or 5) AND
-- all their FEC source donations are D-party AND
-- no other Republican source (rncid, nc_donor_summary) exists

CREATE TEMP TABLE contacts_to_remove AS
SELECT DISTINCT c.contact_id
FROM contacts c
WHERE c.source_detail IN (
    'unmatched_donor',
    'name_zip_match_via_fec',
    'addr_num_match_via_fec'
)
AND c.voter_id IS NULL  -- unmatched contacts from FEC
AND NOT EXISTS (
    -- No Republican FEC donations for this name+zip
    SELECT 1
    FROM v_individual_donations vid  -- already filtered to R/PAC/UNKNOWN
    WHERE UPPER(vid.contributor_last) = c.last_name
    AND UPPER(vid.contributor_first) = c.first_name
    AND vid.contributor_zip5 = c.zip_code
);

-- Check: how many contacts to remove?
SELECT COUNT(*) AS contacts_to_remove FROM contacts_to_remove;
-- Expected: significant number — likely 50K-100K

-- Also identify matched contacts (with voter_id) that are D-only:
CREATE TEMP TABLE matched_contacts_to_remove AS
SELECT DISTINCT c.contact_id
FROM contacts c
WHERE c.source_detail IN ('name_zip_match_via_fec', 'addr_num_match_via_fec')
AND c.voter_id IS NOT NULL
AND NOT EXISTS (
    SELECT 1
    FROM v_individual_donations vid
    WHERE UPPER(vid.contributor_last) = c.last_name
    AND UPPER(vid.contributor_first) = c.first_name
    AND vid.contributor_zip5 = c.zip_code
);

SELECT COUNT(*) AS matched_contacts_to_remove FROM matched_contacts_to_remove;

-- -----------------------------------------------------------------------
-- STEP 3: Delete D-only contacts and their source links
-- *** REQUIRES "I authorize this action" from Ed ***
-- -----------------------------------------------------------------------

-- First: remove person_source_links for these contacts
-- DELETE FROM person_source_links
-- WHERE person_id IN (SELECT contact_id FROM contacts_to_remove)
--    OR person_id IN (SELECT contact_id FROM matched_contacts_to_remove);

-- Then: remove the contacts
-- DELETE FROM contacts
-- WHERE contact_id IN (SELECT contact_id FROM contacts_to_remove)
--    OR contact_id IN (SELECT contact_id FROM matched_contacts_to_remove);

-- -----------------------------------------------------------------------
-- STEP 4: Validation after cleanup
-- -----------------------------------------------------------------------

SELECT COUNT(*) AS total_contacts FROM contacts;
SELECT COUNT(*) AS voter_linked FROM contacts WHERE voter_id IS NOT NULL;
SELECT COUNT(*) AS unmatched FROM contacts WHERE voter_id IS NULL;
-- Expected: total should drop from 434,165 to ~300-350K range
-- All remaining contacts should have at least one R/PAC donation

-- Confirm no D-only contacts remain
SELECT COUNT(*) AS should_be_zero
FROM contacts c
WHERE c.source_detail IN ('unmatched_donor','name_zip_match_via_fec','addr_num_match_via_fec')
AND NOT EXISTS (
    SELECT 1 FROM v_individual_donations vid
    WHERE UPPER(vid.contributor_last) = c.last_name
    AND UPPER(vid.contributor_first) = c.first_name
    AND vid.contributor_zip5 = c.zip_code
);
