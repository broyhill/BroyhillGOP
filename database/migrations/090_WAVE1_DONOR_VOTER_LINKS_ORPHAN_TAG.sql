-- 090_WAVE1_DONOR_VOTER_LINKS_ORPHAN_TAG.sql
-- Wave 1: Tag donor_voter_links rows where donor_id does not resolve to donor_contacts.
-- Non-destructive: no DELETE. Based on fix_02_donor_voter_links_orphans.sql (2026-03-28).
--
-- Run: psql "$SUPABASE_DB_URL" -v ON_ERROR_STOP=1 -f database/migrations/090_WAVE1_DONOR_VOTER_LINKS_ORPHAN_TAG.sql
--
-- Prerequisites: public.donor_voter_links; public.donor_contacts (if missing, only format columns are added).

ALTER TABLE public.donor_voter_links
    ADD COLUMN IF NOT EXISTS donor_id_format TEXT,
    ADD COLUMN IF NOT EXISTS is_orphaned BOOLEAN DEFAULT FALSE,
    ADD COLUMN IF NOT EXISTS orphan_checked_at TIMESTAMPTZ;

COMMENT ON COLUMN public.donor_voter_links.donor_id_format IS
    'uuid | integer | other — Wave 1 orphan audit.';
COMMENT ON COLUMN public.donor_voter_links.is_orphaned IS
    'TRUE if donor_id does not resolve to donor_contacts (uuid rows treated as orphaned).';
COMMENT ON COLUMN public.donor_voter_links.orphan_checked_at IS
    'Last time orphan tagging ran.';

-- Classify donor_id shape
UPDATE public.donor_voter_links
SET donor_id_format = CASE
    WHEN donor_id ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN 'uuid'
    WHEN donor_id ~ '^[0-9]+$' THEN 'integer'
    ELSE 'other'
END
WHERE donor_id_format IS NULL;

-- Resolve against donor_contacts when that table exists
DO $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'donor_contacts'
  ) THEN
    UPDATE public.donor_voter_links dvl
    SET
      is_orphaned = CASE
        WHEN dvl.donor_id_format = 'integer' THEN (dc.contact_id IS NULL)
        WHEN dvl.donor_id_format = 'uuid' THEN TRUE
        ELSE TRUE
      END,
      orphan_checked_at = NOW()
    FROM (
      SELECT d.id AS dvl_id, c.id AS contact_id
      FROM public.donor_voter_links d
      LEFT JOIN public.donor_contacts c
        ON d.donor_id_format = 'integer'
       AND c.id::text = d.donor_id
    ) dc
    WHERE dvl.id = dc.dvl_id;
  ELSE
    RAISE NOTICE '090_WAVE1: public.donor_contacts not found; is_orphaned not updated.';
  END IF;
END $$;
