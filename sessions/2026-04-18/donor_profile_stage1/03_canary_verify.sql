-- =====================================================================
-- Stage 1 Donor Identity — CANARY VERIFICATION (read-only)
-- =====================================================================
-- Run after 02_populate_donor_profile.sql to see every expected signal
-- in one pass. Safe to re-run any time.
-- =====================================================================

\echo '=== 1. Row count parity: profile rows should equal distinct clusters on spine ==='
SELECT
    (SELECT COUNT(*) FROM core.donor_profile)                       AS profile_rows,
    (SELECT COUNT(DISTINCT cluster_id) FROM raw.ncboe_donations)    AS spine_clusters,
    (SELECT COUNT(*) FROM raw.ncboe_donations)                      AS spine_rows;
-- Expected: profile_rows = spine_clusters = 98,303; spine_rows = 321,348

\echo ''
\echo '=== 2. Ed canary (cluster 372171) ==='
SELECT
    cluster_id,
    display_name,
    norm_first,
    norm_last,
    txn_count,
    lifetime_total,
    largest_gift,
    first_gift_date,
    last_gift_date,
    committee_count,
    candidate_count,
    cell_phone,
    personal_email,
    business_email,
    trump_rally_donor,
    has_voter_match
FROM core.donor_profile
WHERE cluster_id = 372171;
-- Expected: txn_count=147 | lifetime_total=332631.30 | personal_email=ed@broyhill.net
-- Absolutely NOT: personal_email=jsneeden@msn.com

\echo ''
\echo '=== 3. Apollo bad-email check across ALL clusters (should return 0 rows) ==='
SELECT cluster_id, display_name, personal_email
FROM core.donor_profile
WHERE personal_email = 'jsneeden@msn.com';
-- Expected: 0 rows

\echo ''
\echo '=== 4. Ed canary parity against the spine (MUST match) ==='
SELECT
    'profile'  AS src,
    COUNT(*)                                                AS txns,
    SUM(lifetime_total)                                     AS total
FROM core.donor_profile
WHERE cluster_id = 372171
UNION ALL
SELECT
    'spine',
    COUNT(*),
    SUM(norm_amount)
FROM raw.ncboe_donations
WHERE cluster_id = 372171;
-- Both rows must match: 147 / 332631.30

\echo ''
\echo '=== 5. Ed Family Office rollup (Layer 2 preview — not yet attributed) ==='
-- This is a PREVIEW showing what the Layer-2 rollup would total. It does NOT
-- write anything to core.donor_attribution. Seeding donor_attribution requires
-- Ed typing `I AUTHORIZE THIS ACTION` on a dedicated DRY RUN.
SELECT
    'ed_family_office'                                      AS rollup_label,
    COUNT(DISTINCT cluster_id)                              AS cluster_count,
    SUM(txn_count)                                          AS total_txns,
    SUM(lifetime_total)                                     AS total_dollars
FROM core.donor_profile
WHERE cluster_id IN (
    372171,   -- Ed (James Edgar Broyhill II)
    2480462,  -- Louise Robbins Broyhill (mother)
    2132854   -- Clemmons address cluster
);
-- Expected: total_dollars = 344,031.30 (if all three clusters exist in profile)
-- If any cluster is absent (not in the spine), investigate before seeding
-- core.donor_attribution. Do NOT fold in Penn (372201/05/09), Melanie Morris,
-- Jim II (397766), or any NC Broyhill cousins.

\echo ''
\echo '=== 6. Top 20 donors by lifetime_total (sanity check) ==='
SELECT
    cluster_id,
    display_name,
    city, state, zip5,
    txn_count,
    lifetime_total,
    committee_count,
    candidate_count,
    has_voter_match
FROM core.donor_profile
ORDER BY lifetime_total DESC NULLS LAST
LIMIT 20;
-- Eyeball test: no obvious junk, no inflated cluster, Ed appears near the top

\echo ''
\echo '=== 7. Contact coverage ==='
SELECT
    COUNT(*)                                                AS total_profiles,
    COUNT(cell_phone)                                       AS with_cell,
    COUNT(home_phone)                                       AS with_home,
    COUNT(personal_email)                                   AS with_p_email,
    COUNT(business_email)                                   AS with_b_email,
    COUNT(rnc_regid)                                        AS with_voter_match,
    COUNT(*) FILTER (WHERE trump_rally_donor)               AS trump_rally_donors
FROM core.donor_profile;
-- Eyeball: does not have to match pre-TRUNCATE exactly; what matters is that
-- the rollup didn't drop clusters. If with_voter_match is 0, the rnc_regid
-- column on raw is empty and we need to reinstate DataTrust enrichment first.

\echo ''
\echo '=== 8. Audit row just written ==='
SELECT *
FROM core.donor_profile_audit
ORDER BY id DESC
LIMIT 3;

\echo ''
\echo '=== 9. Business-address bridge: industry coverage ==='
SELECT
    COUNT(*)                                                AS total,
    COUNT(employer_normalized)                              AS with_employer_norm,
    COUNT(sic_code)                                         AS with_sic,
    COUNT(*) FILTER (WHERE sic_match_method = 'EMPLOYER_KEYWORD') AS via_keyword,
    COUNT(*) FILTER (WHERE sic_match_method = 'PROFESSION')        AS via_profession,
    ROUND(100.0 * COUNT(sic_code) / NULLIF(COUNT(*),0), 1) AS pct_sic
FROM core.donor_profile;
-- Expected after bridge: with_sic > 0 and non-trivial; pct_sic shows the
-- industry hit rate. Prior rough target (per skills): well over half of
-- clusters with a non-null employer should land on a SIC code.

\echo ''
\echo '=== 10. Business-address bridge: address classification ==='
SELECT
    address_class,
    COUNT(*) AS rows,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct
FROM core.donor_profile
GROUP BY address_class
ORDER BY rows DESC;
-- Expected: HOME / BUSINESS / UNKNOWN mix. Per skills, ~75% of wealthy-donor
-- filings are business addresses, so expect a material BUSINESS slice.

\echo ''
\echo '=== 11. Business-address bridge: dark-donor business-likely coverage ==='
SELECT
    COUNT(*)                                                      AS total_dark,
    COUNT(*) FILTER (WHERE dark_donor_business_likely)            AS flagged_business,
    ROUND(100.0 * COUNT(*) FILTER (WHERE dark_donor_business_likely)
                / NULLIF(COUNT(*),0), 1)                          AS pct_flagged
FROM core.donor_profile
WHERE has_voter_match = FALSE;
-- Expected: total_dark ≈ 17,698. flagged_business > 0 (real thousands).

\echo ''
\echo '=== 12. Top 10 industries by lifetime giving ==='
SELECT
    COALESCE(industry_sector, '(unclassified)') AS industry,
    COUNT(*)                                    AS clusters,
    SUM(lifetime_total)                         AS dollars
FROM core.donor_profile
GROUP BY 1
ORDER BY dollars DESC NULLS LAST
LIMIT 10;

\echo ''
\echo '=== 13. Ed 372171 bridge check (sic + address class — informational) ==='
SELECT cluster_id, employer, employer_normalized,
       sic_code, sic_division, industry_sector,
       sic_match_method, sic_match_confidence, sic_matched_pattern,
       address_class, home_matches_voter,
       voter_home_street, street_line_1
  FROM core.donor_profile
 WHERE cluster_id = 372171;
-- Informational only. Anvil Venture Group isn't in the 272-keyword list
-- (added as a variant in core.normalize_employer). Expect employer_normalized
-- = 'ANVIL VENTURE GROUP'. SIC likely lands via profession fallback OR is
-- NULL if no job_title is populated. Flag here is documentary, not a gate.

\echo ''
\echo '=== DONE. If any row above looks wrong, DO NOT PROCEED. Send Nexus the output. ==='
