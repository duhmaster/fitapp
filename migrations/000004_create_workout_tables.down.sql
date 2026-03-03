DROP INDEX IF EXISTS idx_exercise_logs_exercise_id;
DROP INDEX IF EXISTS idx_exercise_logs_workout_id;
DROP INDEX IF EXISTS idx_workout_exercises_exercise_id;
DROP INDEX IF EXISTS idx_workout_exercises_workout_id;
DROP INDEX IF EXISTS idx_workouts_scheduled_at;
DROP INDEX IF EXISTS idx_workouts_user_created;
DROP INDEX IF EXISTS idx_workouts_template_id;
DROP INDEX IF EXISTS idx_workouts_user_id;
DROP INDEX IF EXISTS idx_workout_templates_created_by;

DROP TABLE IF EXISTS exercise_logs;
DROP TABLE IF EXISTS workout_exercises;
DROP TABLE IF EXISTS workouts;
DROP TABLE IF EXISTS workout_templates;
DROP TABLE IF EXISTS exercises;
