DROP INDEX IF EXISTS idx_workouts_trainer_id;
ALTER TABLE workouts DROP COLUMN IF EXISTS trainer_id;

DROP INDEX IF EXISTS idx_trainer_photos_trainer_user_id;
DROP TABLE IF EXISTS trainer_photos;
DROP TABLE IF EXISTS trainer_profiles;
