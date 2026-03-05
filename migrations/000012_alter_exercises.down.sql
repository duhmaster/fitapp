DROP INDEX IF EXISTS idx_exercises_is_popular;
DROP INDEX IF EXISTS idx_exercises_tags;
DROP INDEX IF EXISTS idx_exercises_difficulty_level;
DROP INDEX IF EXISTS idx_exercises_muscle_group;

ALTER TABLE exercises DROP COLUMN IF EXISTS is_free;
ALTER TABLE exercises DROP COLUMN IF EXISTS is_popular;
ALTER TABLE exercises DROP COLUMN IF EXISTS is_base;
ALTER TABLE exercises DROP COLUMN IF EXISTS difficulty_level;
ALTER TABLE exercises DROP COLUMN IF EXISTS formula;
ALTER TABLE exercises DROP COLUMN IF EXISTS muscle_loads;
ALTER TABLE exercises DROP COLUMN IF EXISTS instruction;
ALTER TABLE exercises DROP COLUMN IF EXISTS description;
ALTER TABLE exercises DROP COLUMN IF EXISTS tags;
DROP INDEX IF EXISTS idx_workouts_program_id;
ALTER TABLE workouts DROP COLUMN IF EXISTS program_id;

ALTER TABLE exercises DROP COLUMN IF EXISTS equipment;
