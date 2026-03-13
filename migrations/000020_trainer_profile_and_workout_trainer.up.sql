-- Trainer profile (about, contacts); trainer photos; workouts.trainer_id

CREATE TABLE trainer_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    about_me TEXT,
    contacts TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE trainer_photos (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    path VARCHAR(512) NOT NULL,
    position INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_trainer_photos_trainer_user_id ON trainer_photos(trainer_user_id);

ALTER TABLE workouts ADD COLUMN IF NOT EXISTS trainer_id UUID REFERENCES users(id) ON DELETE SET NULL;
CREATE INDEX IF NOT EXISTS idx_workouts_trainer_id ON workouts(trainer_id);
