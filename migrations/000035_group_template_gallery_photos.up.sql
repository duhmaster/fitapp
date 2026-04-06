-- Up to 3 gallery images per group training template (ordered); photo_id stays first id for list joins.
ALTER TABLE group_training_templates
  ADD COLUMN IF NOT EXISTS gallery_photo_ids UUID[] NOT NULL DEFAULT '{}';

ALTER TABLE group_training_templates
  DROP CONSTRAINT IF EXISTS group_training_templates_gallery_len;

ALTER TABLE group_training_templates
  ADD CONSTRAINT group_training_templates_gallery_len CHECK (cardinality(gallery_photo_ids) <= 3);

UPDATE group_training_templates
SET gallery_photo_ids = ARRAY[photo_id]::uuid[]
WHERE photo_id IS NOT NULL
  AND cardinality(gallery_photo_ids) = 0;
