DROP TABLE IF EXISTS template_exercise_sets;
DROP TABLE IF EXISTS workout_template_exercises;
ALTER TABLE workout_templates DROP COLUMN IF EXISTS deleted_at;
