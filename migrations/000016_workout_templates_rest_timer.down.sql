ALTER TABLE workout_templates
  DROP COLUMN IF EXISTS use_rest_timer,
  DROP COLUMN IF EXISTS rest_seconds;
