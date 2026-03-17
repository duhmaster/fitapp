ALTER TABLE workouts
    ADD COLUMN IF NOT EXISTS gym_id UUID REFERENCES gyms(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_workouts_gym_id ON workouts(gym_id);

