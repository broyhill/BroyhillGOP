-- ============================================================================
-- E49 STORAGE BUCKETS - Supabase Storage Setup for Voice/Photo/Video
-- ============================================================================
-- Run this in Supabase SQL Editor to create storage buckets and tables

-- Create storage buckets
INSERT INTO storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
VALUES 
  ('voice-samples', 'voice-samples', true, 52428800, ARRAY['audio/wav', 'audio/mpeg', 'audio/mp4', 'audio/ogg', 'audio/webm']),
  ('candidate-photos', 'candidate-photos', true, 10485760, ARRAY['image/jpeg', 'image/png', 'image/webp']),
  ('generated-videos', 'generated-videos', true, 524288000, ARRAY['video/mp4', 'video/webm'])
ON CONFLICT (id) DO NOTHING;

-- RLS policies for voice-samples bucket
CREATE POLICY "Allow authenticated uploads to voice-samples" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'voice-samples');
CREATE POLICY "Allow public read from voice-samples" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'voice-samples');

-- RLS policies for candidate-photos bucket
CREATE POLICY "Allow authenticated uploads to candidate-photos" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'candidate-photos');
CREATE POLICY "Allow public read from candidate-photos" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'candidate-photos');

-- RLS policies for generated-videos bucket
CREATE POLICY "Allow authenticated uploads to generated-videos" ON storage.objects
  FOR INSERT TO authenticated WITH CHECK (bucket_id = 'generated-videos');
CREATE POLICY "Allow public read from generated-videos" ON storage.objects
  FOR SELECT TO public USING (bucket_id = 'generated-videos');

-- Voice extraction jobs table
CREATE TABLE IF NOT EXISTS voice_extraction_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id UUID NOT NULL REFERENCES candidates(id),
  youtube_url TEXT NOT NULL,
  status TEXT DEFAULT 'queued',
  progress INTEGER DEFAULT 0,
  sample_url TEXT,
  error TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Candidate photos table
CREATE TABLE IF NOT EXISTS candidate_photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  candidate_id UUID NOT NULL REFERENCES candidates(id),
  storage_path TEXT NOT NULL,
  public_url TEXT,
  photo_type TEXT DEFAULT 'headshot',
  is_primary BOOLEAN DEFAULT false,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Video jobs table (for worker.py polling)
CREATE TABLE IF NOT EXISTS video_jobs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  job_type TEXT DEFAULT 'video_generation',
  status TEXT DEFAULT 'pending',
  progress INTEGER DEFAULT 0,
  candidate_id UUID NOT NULL REFERENCES candidates(id),
  input_data JSONB,
  output_data JSONB,
  error TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes
CREATE INDEX IF NOT EXISTS idx_voice_extraction_jobs_candidate ON voice_extraction_jobs(candidate_id);
CREATE INDEX IF NOT EXISTS idx_voice_extraction_jobs_status ON voice_extraction_jobs(status);
CREATE INDEX IF NOT EXISTS idx_candidate_photos_candidate ON candidate_photos(candidate_id);
CREATE INDEX IF NOT EXISTS idx_video_jobs_candidate ON video_jobs(candidate_id);
CREATE INDEX IF NOT EXISTS idx_video_jobs_status ON video_jobs(status);

-- Auto-update triggers
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER voice_extraction_jobs_updated BEFORE UPDATE ON voice_extraction_jobs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER candidate_photos_updated BEFORE UPDATE ON candidate_photos
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER video_jobs_updated BEFORE UPDATE ON video_jobs
  FOR EACH ROW EXECUTE FUNCTION update_updated_at();
