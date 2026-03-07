-- ============================================================================
-- 054_CANDIDATE_COMMITTEE_MAPPING.sql
-- BroyhillGOP: Candidate ⇄ Committee ⇄ Transactions linkage
-- ============================================================================
-- Goal:
-- - Create an explicit mapping between candidates and committees.
-- - Make it easy to see which candidate a transaction ultimately benefits.
-- - Do this without breaking existing tables (non-destructive).
--
-- Existing tables (from 02_schema_remaining_tables.sql):
--   candidates(candidate_id, tenant_id, full_name, office_sought, office_level,
--              district, state, fec_candidate_id, fec_committee_id, ...)
--   committees(committee_id, tenant_id, committee_name, committee_type,
--              fec_committee_id, ...)
--   transactions(transaction_id, donor_id, tenant_id,
--                recipient_type, recipient_id, recipient_name, ...)
--
-- This migration adds:
--   1) candidate_committee_map  (manual + scripted mapping layer)
--   2) v_transactions_with_candidate  (view to expose candidate_id on transactions)
--
-- Run order:
--   - Safe to run at any time; does not drop or alter existing tables.
-- ============================================================================ 

BEGIN;

-- ---------------------------------------------------------------------------
-- 1. Candidate ⇄ Committee mapping table
-- ---------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS candidate_committee_map (
    candidate_id   UUID NOT NULL REFERENCES candidates(candidate_id) ON DELETE CASCADE,
    committee_id   UUID NOT NULL REFERENCES committees(committee_id) ON DELETE CASCADE,

    -- Flags and metadata
    is_primary     BOOLEAN DEFAULT FALSE,
    source_system  VARCHAR(50),          -- 'fec', 'nc_boe', 'manual', etc.
    cycle          INTEGER,              -- election year (e.g. 2024)

    -- Optional cached IDs for easier joins from raw FEC/BOE tables
    fec_candidate_id  VARCHAR(50),
    fec_committee_id  VARCHAR(50),

    created_at    TIMESTAMPTZ DEFAULT NOW(),
    created_by    VARCHAR(255),

    PRIMARY KEY (candidate_id, committee_id)
);

CREATE INDEX IF NOT EXISTS idx_ccm_committee ON candidate_committee_map(committee_id);
CREATE INDEX IF NOT EXISTS idx_ccm_fec_ids
    ON candidate_committee_map(fec_candidate_id, fec_committee_id);


-- ---------------------------------------------------------------------------
-- 2. View: transactions with resolved candidate
-- ---------------------------------------------------------------------------
-- Logic:
--   - If transactions.recipient_type = 'candidate' and recipient_id points
--     at candidates.candidate_id, use that directly.
--   - If recipient_type = 'committee', join committees → candidate_committee_map
--     to find the candidate.
--   - If no mapping exists, candidate_id will be NULL.
--
-- NOTE: This view does not change data; it just exposes a consistent
--       candidate_id for analytics, portals, and RLS.
-- ---------------------------------------------------------------------------

CREATE OR REPLACE VIEW v_transactions_with_candidate AS
WITH base AS (
    SELECT
        t.*,
        CASE
            WHEN t.recipient_type = 'candidate' THEN t.recipient_id
            ELSE NULL::UUID
        END AS direct_candidate_id
    FROM transactions t
),
by_committee AS (
    SELECT
        b.*,
        cm.candidate_id AS mapped_candidate_id
    FROM base b
    LEFT JOIN committees c
      ON b.recipient_type = 'committee'
     AND b.recipient_id = c.committee_id
    LEFT JOIN candidate_committee_map cm
      ON cm.committee_id = c.committee_id
)
SELECT
    bc.*,
    COALESCE(bc.direct_candidate_id, bc.mapped_candidate_id) AS candidate_id
FROM by_committee bc;


COMMIT;

