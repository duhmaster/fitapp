ALTER TABLE group_training_templates DROP COLUMN IF EXISTS photo_id;
DROP INDEX IF EXISTS idx_group_training_templates_photo_id;

DROP TABLE IF EXISTS photos;
DROP TABLE IF EXISTS buckets;
