-- Soft delete for workout_templates
ALTER TABLE workout_templates
  ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- Template exercises (exercises in a template with order)
CREATE TABLE IF NOT EXISTS workout_template_exercises (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES workout_templates(id) ON DELETE CASCADE,
  exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
  exercise_order INT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workout_template_exercises_template_id ON workout_template_exercises(template_id);
CREATE INDEX IF NOT EXISTS idx_workout_template_exercises_exercise_id ON workout_template_exercises(exercise_id);

-- Sets per template exercise (weight, reps per set)
CREATE TABLE IF NOT EXISTS template_exercise_sets (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_exercise_id UUID NOT NULL REFERENCES workout_template_exercises(id) ON DELETE CASCADE,
  set_order INT NOT NULL DEFAULT 0,
  weight_kg DECIMAL(6,2),
  reps INT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_template_exercise_sets_template_exercise_id ON template_exercise_sets(template_exercise_id);
