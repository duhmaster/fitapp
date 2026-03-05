-- FITFLOW: Extend exercises table with JSON catalog fields

ALTER TABLE exercises ADD COLUMN IF NOT EXISTS equipment TEXT[] DEFAULT '{}';
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS tags TEXT[] DEFAULT '{}';
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS description TEXT;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS instruction TEXT[] DEFAULT '{}';
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS muscle_loads JSONB DEFAULT '{}';
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS formula TEXT;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS difficulty_level VARCHAR(50);
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS is_base BOOLEAN DEFAULT FALSE;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS is_popular BOOLEAN DEFAULT FALSE;
ALTER TABLE exercises ADD COLUMN IF NOT EXISTS is_free BOOLEAN DEFAULT TRUE;

CREATE INDEX IF NOT EXISTS idx_exercises_muscle_group ON exercises(muscle_group);
CREATE INDEX IF NOT EXISTS idx_exercises_difficulty_level ON exercises(difficulty_level);
CREATE INDEX IF NOT EXISTS idx_exercises_tags ON exercises USING GIN(tags);
CREATE INDEX IF NOT EXISTS idx_exercises_is_popular ON exercises(is_popular) WHERE is_popular = TRUE;

ALTER TABLE workouts ADD COLUMN IF NOT EXISTS program_id UUID REFERENCES programs(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_workouts_program_id ON workouts(program_id);
