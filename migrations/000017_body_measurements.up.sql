-- Body measurements history (weight, body fat %, height for FFMI/BMI)
CREATE TABLE IF NOT EXISTS body_measurements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    weight_kg DECIMAL(5,2) NOT NULL,
    body_fat_pct DECIMAL(4,2),
    height_cm DECIMAL(5,2)
);

CREATE INDEX IF NOT EXISTS idx_body_measurements_user_id ON body_measurements(user_id);
CREATE INDEX IF NOT EXISTS idx_body_measurements_user_recorded ON body_measurements(user_id, recorded_at DESC);
