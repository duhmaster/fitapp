-- User profile: city (for 2GIS and gym selection)
ALTER TABLE user_profiles
  ADD COLUMN IF NOT EXISTS city VARCHAR(255);

-- Gyms: city and contact info
ALTER TABLE gyms
  ADD COLUMN IF NOT EXISTS city VARCHAR(255),
  ADD COLUMN IF NOT EXISTS contact_phone VARCHAR(100),
  ADD COLUMN IF NOT EXISTS contact_url VARCHAR(512);

-- Many-to-many: users <-> gyms (my gyms)
CREATE TABLE IF NOT EXISTS user_gyms (
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  gym_id UUID NOT NULL REFERENCES gyms(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, gym_id)
);
CREATE INDEX IF NOT EXISTS idx_user_gyms_user_id ON user_gyms(user_id);
CREATE INDEX IF NOT EXISTS idx_user_gyms_gym_id ON user_gyms(gym_id);
