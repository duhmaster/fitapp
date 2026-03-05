-- Rest timer settings for workout templates
ALTER TABLE workout_templates
  ADD COLUMN IF NOT EXISTS use_rest_timer BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS rest_seconds INT NOT NULL DEFAULT 60;
