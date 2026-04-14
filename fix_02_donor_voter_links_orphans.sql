-- =============================================================================
-- FIX 02: donor_voter_links — 65.4% orphaned donor_ids
-- Table: donor_voter_links
-- Issue: donor_id column stores two formats:
--   - UUID format (88,139 rows / 28.5%): look like FEC/internal UUIDs,
--     but do NOT match donor_contacts.id (0 matches), nor winred_donors.id (0 matches)
--   - Integer format (220,964 rows / 71.5%): 106,960 DO match donor_contacts.id,
--     leaving 114,004 integer-format IDs unresolved
-- Diagnosis: UUID-format IDs are fully orphaned (88,139 rows). Integer IDs have
--   114,004 orphans. Total orphaned ≈ 202,143 / 309,103 = 65.4%
-- Columns: id (bigint), donor_id (text), ncid (text), rncid (text),
--          match_method (text), match_confidence (numeric), created_at
-- Estimated rows affected: ~202,143 orphaned rows out of 309,103 total
-- Diagnosed: 2026-03-28
-- =============================================================================

-- -----------------------------------------------------------------------
-- DIAGNOSTIC VERIFICATION
-- -----------------------------------------------------------------------

-- Confirm ID format breakdown
SELECT
    COUNT(CASE WHEN donor_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN 1 END) as uuid_format,
    COUNT(CASE WHEN donor_id ~ '^[0-9]+$' THEN 1 END) as integer_format,
    COUNT(CASE WHEN donor_id NOT SIMILAR TO '%[0-9]%' THEN 1 END) as other_format,
    COUNT(*) as total
FROM donor_voter_links;

-- Check integer-format matches against donor_contacts
SELECT COUNT(*) as integer_matched_donor_contacts
FROM donor_voter_links dvl
JOIN donor_contacts dc ON dc.id::text = dvl.donor_id
WHERE dvl.donor_id ~ '^[0-9]+$';

-- Check UUID-format matches against donor_contacts
SELECT COUNT(*) as uuid_matched_donor_contacts
FROM donor_voter_links dvl
JOIN donor_contacts dc ON dc.id::text = dvl.donor_id
WHERE dvl.donor_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$';

-- Sample orphaned UUID-format records
SELECT donor_id, ncid, rncid, match_method, match_confidence, created_at
FROM donor_voter_links
WHERE donor_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}'
LIMIT 5;

-- -----------------------------------------------------------------------
-- STEP 1: BACKUP (rerun-safe; run outside transaction — DDL)
-- -----------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS donor_voter_links_backup_20260328
(LIKE donor_voter_links INCLUDING DEFAULTS INCLUDING CONSTRAINTS);

INSERT INTO donor_voter_links_backup_20260328
SELECT src.*
FROM donor_voter_links src
WHERE NOT EXISTS (
    SELECT 1
    FROM donor_voter_links_backup_20260328 b
    WHERE b.id = src.id
);

-- Confirm backup row count matches
SELECT
    (SELECT COUNT(*) FROM donor_voter_links) as source_count,
    (SELECT COUNT(*) FROM donor_voter_links_backup_20260328) as backup_count;

-- -----------------------------------------------------------------------
-- STEP 2: Add audit columns (DDL — outside transaction or in separate migration)
-- -----------------------------------------------------------------------
ALTER TABLE donor_voter_links
    ADD COLUMN IF NOT EXISTS donor_id_format TEXT,
    ADD COLUMN IF NOT EXISTS is_orphaned BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS orphan_checked_at TIMESTAMPTZ;

COMMENT ON COLUMN donor_voter_links.donor_id_format IS
    'Format classification of donor_id: uuid, integer, or other. Added 2026-03-28.';
COMMENT ON COLUMN donor_voter_links.is_orphaned IS
    'TRUE if donor_id cannot be resolved to any known donor table. Added 2026-03-28.';
COMMENT ON COLUMN donor_voter_links.orphan_checked_at IS
    'Timestamp when orphan check was last performed.';

-- -----------------------------------------------------------------------
-- STEP 3: Tag rows by ID format
-- -----------------------------------------------------------------------
BEGIN;

UPDATE donor_voter_links
SET donor_id_format = CASE
    WHEN donor_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN 'uuid'
    WHEN donor_id ~ '^[0-9]+$' THEN 'integer'
    ELSE 'other'
END
WHERE donor_id_format IS NULL;

-- Verify tagging
SELECT donor_id_format, COUNT(*) FROM donor_voter_links GROUP BY donor_id_format;

COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- STEP 4: Single-pass orphan resolution (atomic + idempotent)
-- -----------------------------------------------------------------------
BEGIN;

UPDATE donor_voter_links dvl
SET
    is_orphaned = CASE
        WHEN dvl.donor_id_format = 'integer' THEN (dc.id IS NULL)
        WHEN dvl.donor_id_format = 'uuid' THEN TRUE
        ELSE TRUE
    END,
    orphan_checked_at = NOW()
FROM (
    SELECT d.id AS dvl_id, c.id
    FROM donor_voter_links d
    LEFT JOIN donor_contacts c
      ON d.donor_id_format = 'integer'
     AND c.id::text = d.donor_id
) dc
WHERE dvl.id = dc.dvl_id
;

-- Verify orphan counts
SELECT
    donor_id_format,
    COUNT(*) as total,
    COUNT(CASE WHEN is_orphaned = TRUE THEN 1 END) as orphaned,
    COUNT(CASE WHEN is_orphaned = FALSE THEN 1 END) as resolved,
    COUNT(CASE WHEN is_orphaned IS NULL THEN 1 END) as unchecked
FROM donor_voter_links
GROUP BY donor_id_format;

COMMIT;
-- ROLLBACK;

-- -----------------------------------------------------------------------
-- STEP 5: FK constraint (add AFTER cleaning — only once orphans are resolved)
-- -----------------------------------------------------------------------
-- NOTE: Do NOT run this step until orphaned rows are either deleted or
-- donor_contacts is populated with the missing IDs.
-- This is provided as a template for when the data is clean.

-- FK OPTIONS (pick one after schema decision):
-- Option A (recommended): add typed bigint donor_contact_id, backfill from integer donor_id,
-- then enforce FK donor_contact_id -> donor_contacts(id).
--
-- ALTER TABLE donor_voter_links ADD COLUMN donor_contact_id BIGINT;
-- UPDATE donor_voter_links
-- SET donor_contact_id = donor_id::bigint
-- WHERE donor_id_format = 'integer' AND donor_id ~ '^[0-9]+$';
-- ALTER TABLE donor_voter_links
--   ADD CONSTRAINT fk_dvl_donor_contact
--   FOREIGN KEY (donor_contact_id) REFERENCES donor_contacts(id) NOT VALID;
-- ALTER TABLE donor_voter_links VALIDATE CONSTRAINT fk_dvl_donor_contact;
--
-- Option B: if donor_contacts.id is TEXT in your environment, use direct text FK.

-- -----------------------------------------------------------------------
-- ROLLBACK INSTRUCTIONS
-- -----------------------------------------------------------------------
-- -- To revert audit columns:
-- BEGIN;
-- ALTER TABLE donor_voter_links
--     DROP COLUMN IF EXISTS donor_id_format,
--     DROP COLUMN IF EXISTS is_orphaned,
--     DROP COLUMN IF EXISTS orphan_checked_at;
-- COMMIT;
--
-- -- To restore from backup (nuclear option):
-- BEGIN;
-- TRUNCATE donor_voter_links;
-- INSERT INTO donor_voter_links SELECT id, donor_id, ncid, rncid, match_method, match_confidence, created_at
-- FROM donor_voter_links_backup_20260328;
-- COMMIT;
