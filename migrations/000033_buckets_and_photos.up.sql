-- Buckets (S3 storage reference)
CREATE TABLE IF NOT EXISTS buckets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  endpoint VARCHAR(512) NOT NULL DEFAULT '',
  region VARCHAR(64) NOT NULL DEFAULT '',
  public_url VARCHAR(512) NOT NULL DEFAULT '',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO buckets (name, endpoint, region, public_url) VALUES
  ('local', '', '', 'http://localhost:8080/uploads'),
  ('gymmore', 's3.ru-7.storage.selcloud.ru', 'ru-7', 'http://s3.gymmore.ru')
ON CONFLICT (name) DO NOTHING;

-- Photos (centralized table for all uploaded images)
CREATE TABLE IF NOT EXISTS photos (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  bucket_id UUID NOT NULL REFERENCES buckets(id) ON DELETE RESTRICT,
  object_key VARCHAR(512) NOT NULL,
  url VARCHAR(1024) NOT NULL,
  uploaded_by_user_id UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_photos_bucket_id ON photos(bucket_id);
CREATE INDEX IF NOT EXISTS idx_photos_uploaded_by ON photos(uploaded_by_user_id);
CREATE UNIQUE INDEX IF NOT EXISTS idx_photos_bucket_object ON photos(bucket_id, object_key);

-- Add photo_id to group_training_templates (nullable; photo_path kept for backward compatibility)
ALTER TABLE group_training_templates
  ADD COLUMN IF NOT EXISTS photo_id UUID REFERENCES photos(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_group_training_templates_photo_id ON group_training_templates(photo_id);
