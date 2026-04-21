CREATE TABLE IF NOT EXISTS workout_feedback (
  workout_id UUID PRIMARY KEY REFERENCES workouts(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  session_quality SMALLINT NOT NULL CHECK (session_quality BETWEEN 1 AND 5),
  overall_wellbeing SMALLINT NOT NULL CHECK (overall_wellbeing BETWEEN 1 AND 5),
  fatigue SMALLINT NOT NULL CHECK (fatigue BETWEEN 1 AND 10),
  muscle_soreness SMALLINT CHECK (muscle_soreness BETWEEN 0 AND 10),
  pain_discomfort SMALLINT CHECK (pain_discomfort BETWEEN 0 AND 10),
  stress_level SMALLINT CHECK (stress_level BETWEEN 1 AND 5),
  sleep_hours NUMERIC(4,1) CHECK (sleep_hours >= 0 AND sleep_hours <= 24),
  sleep_quality SMALLINT CHECK (sleep_quality BETWEEN 1 AND 5),
  note TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_workout_feedback_user_id ON workout_feedback(user_id);
