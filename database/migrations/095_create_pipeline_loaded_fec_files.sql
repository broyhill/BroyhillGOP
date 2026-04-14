-- Migration 095: Create pipeline.loaded_fec_files
-- Authorized by: Ed Broyhill, April 8, 2026
-- Purpose: FEC ingestion idempotency guard — mirrors pipeline.loaded_ncboe_files pattern

CREATE TABLE IF NOT EXISTS pipeline.loaded_fec_files (
    id              serial PRIMARY KEY,
    file_name       text NOT NULL,
    file_hash       text NOT NULL,
    row_count       integer,
    net_row_count   integer,           -- rows after 4-filter audit (NC only, individual, GOP, no memo)
    memo_rows       integer,           -- memo rows excluded
    org_rows        integer,           -- org/PAC rows excluded
    loaded_at       timestamptz DEFAULT now(),
    loaded_by       text DEFAULT 'cursor',
    status          text DEFAULT 'complete',
    notes           text,
    CONSTRAINT loaded_fec_files_hash_unique UNIQUE (file_hash)
);

-- Index for fast lookups by filename
CREATE INDEX IF NOT EXISTS idx_loaded_fec_files_file_name
    ON pipeline.loaded_fec_files (file_name);

-- Seed with the 14 already-loaded files (row counts from fec_donations)
INSERT INTO pipeline.loaded_fec_files
    (file_name, file_hash, row_count, loaded_at, status, notes)
SELECT
    source_file,
    md5(source_file),          -- placeholder hash — real hash not available for already-loaded files
    COUNT(*),
    MIN(created_at),
    'complete',
    'Pre-095 load — seeded from fec_donations.source_file; hash is placeholder'
FROM public.fec_donations
GROUP BY source_file
ON CONFLICT (file_hash) DO NOTHING;

-- Post-check:
-- SELECT file_name, row_count, loaded_at FROM pipeline.loaded_fec_files ORDER BY loaded_at;
-- Expected: 14 rows matching fec_donations source files
