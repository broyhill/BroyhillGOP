-- ============================================================
-- committee_party_donor_golden_build.sql
-- BroyhillGOP / NCRDC — Pure NCBOE GOP Party Committee Donors
-- Source:  committee.v_republican_party_individual_donors  (183,412 rows)
--          committee.v_republican_party_donor_enriched     (183,463 rows)
-- NO FEC data. NO candidate fields. NCBOE only.
--
-- Run via:
--   sudo -u postgres psql -d postgres -v ON_ERROR_STOP=1 \
--     -f /tmp/committee_party_donor_golden_build.sql
-- ============================================================

SET search_path TO committee, public;

-- ────────────────────────────────────────────────────────────
-- 1.  GOLDEN DONOR TABLE  (one row per unique donor identity)
-- ────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS committee.party_donor_golden CASCADE;

CREATE TABLE committee.party_donor_golden AS
WITH base AS (
    SELECT
        e.cluster_id,

        -- Identity
        e.name                          AS raw_name,
        e.norm_name_full                AS norm_name_full,
        e.norm_name_last                AS norm_name_last,
        e.norm_name_first               AS norm_name_first,
        e.norm_name_middle              AS norm_name_middle,
        e.norm_name_suffix              AS norm_name_suffix,
        e.identity_block_key,
        e.identity_key_loose,
        e.identity_anomaly_short_last,
        e.identity_norm_version,

        -- Address (from enriched; canonical for the cluster)
        d.street_line_1,
        d.street_line_2,
        d.city,
        d.state,
        d.zip_code,
        e.norm_zip5,
        e.addr_numeric_tokens,

        -- Profession / employer
        d.profession_job_title,
        d.employer_name,

        -- Committee context (enriched)
        e.committee_sboe_id,
        e.committee_name                AS primary_committee_name,
        e.committee_type,
        e.donor_subtype,
        e.party_flag,

        -- Financial aggregates (from raw transactions)
        COUNT(d.id)                     AS total_transactions,
        SUM(d.norm_amount)              AS total_amount,
        MIN(d.norm_date)                AS first_date,
        MAX(d.norm_date)                AS last_date,

        -- Flags
        BOOL_OR(d.is_aggregated)        AS any_aggregated,

        -- Source tracking
        MIN(d.source_file)              AS source_file_sample,

        -- Metadata
        NOW()                           AS built_at

    FROM committee.v_republican_party_donor_enriched  e
    JOIN committee.v_republican_party_individual_donors d
          ON d.cluster_id = e.cluster_id

    GROUP BY
        e.cluster_id,
        e.name,
        e.norm_name_full,
        e.norm_name_last,
        e.norm_name_first,
        e.norm_name_middle,
        e.norm_name_suffix,
        e.identity_block_key,
        e.identity_key_loose,
        e.identity_anomaly_short_last,
        e.identity_norm_version,
        d.street_line_1,
        d.street_line_2,
        d.city,
        d.state,
        d.zip_code,
        e.norm_zip5,
        e.addr_numeric_tokens,
        d.profession_job_title,
        d.employer_name,
        e.committee_sboe_id,
        e.committee_name,
        e.committee_type,
        e.donor_subtype,
        e.party_flag
)
SELECT * FROM base;

-- Indexes for downstream joins and dedupe lookup
CREATE INDEX idx_pdg_cluster_id        ON committee.party_donor_golden (cluster_id);
CREATE INDEX idx_pdg_block_key         ON committee.party_donor_golden (identity_block_key);
CREATE INDEX idx_pdg_loose_key         ON committee.party_donor_golden (identity_key_loose);
CREATE INDEX idx_pdg_norm_zip5         ON committee.party_donor_golden (norm_zip5);
CREATE INDEX idx_pdg_committee_sboe    ON committee.party_donor_golden (committee_sboe_id);
CREATE INDEX idx_pdg_last_name         ON committee.party_donor_golden (norm_name_last);

-- ────────────────────────────────────────────────────────────
-- 2.  COMMITTEE MAP  (many-to-many: donor ↔ committees)
--     One row per cluster_id / committee_sboe_id pair
-- ────────────────────────────────────────────────────────────
DROP TABLE IF EXISTS committee.party_donor_committee_map CASCADE;

CREATE TABLE committee.party_donor_committee_map AS
SELECT
    d.cluster_id,
    d.committee_sboe_id,
    d.committee_name,
    d.committee_type,
    d.donor_subtype,
    d.party_flag,
    COUNT(r.id)             AS txn_count,
    SUM(r.norm_amount)      AS total_amount,
    MIN(r.norm_date)        AS first_date,
    MAX(r.norm_date)        AS last_date
FROM committee.v_republican_party_donor_enriched   d
JOIN committee.v_republican_party_individual_donors r
      ON r.cluster_id = d.cluster_id
     AND r.committee_sboe_id = d.committee_sboe_id
GROUP BY
    d.cluster_id,
    d.committee_sboe_id,
    d.committee_name,
    d.committee_type,
    d.donor_subtype,
    d.party_flag;

CREATE INDEX idx_pdcm_cluster_id     ON committee.party_donor_committee_map (cluster_id);
CREATE INDEX idx_pdcm_committee_sboe ON committee.party_donor_committee_map (committee_sboe_id);

-- ────────────────────────────────────────────────────────────
-- 3.  VERIFICATION — row counts via pg_stat_user_tables
-- ────────────────────────────────────────────────────────────
ANALYZE committee.party_donor_golden;
ANALYZE committee.party_donor_committee_map;

SELECT
    schemaname,
    relname                 AS table_name,
    n_live_tup              AS estimated_rows
FROM pg_stat_user_tables
WHERE schemaname = 'committee'
  AND relname IN ('party_donor_golden', 'party_donor_committee_map')
ORDER BY relname;
