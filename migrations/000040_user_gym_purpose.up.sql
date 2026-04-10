-- Split user↔gym links: personal (train here) vs coaching (work as trainer).
ALTER TABLE user_gyms
  ADD COLUMN IF NOT EXISTS purpose VARCHAR(20) NOT NULL DEFAULT 'personal';

ALTER TABLE user_gyms DROP CONSTRAINT IF EXISTS user_gyms_pkey;
ALTER TABLE user_gyms ADD PRIMARY KEY (user_id, gym_id, purpose);

CREATE INDEX IF NOT EXISTS idx_user_gyms_user_purpose ON user_gyms (user_id, purpose);

-- Trainers: copy each existing (personal) link as coaching so public profile & group trainings stay valid.
INSERT INTO user_gyms (user_id, gym_id, purpose)
SELECT ug.user_id, ug.gym_id, 'coaching'
  FROM user_gyms ug
  INNER JOIN users u ON u.id = ug.user_id AND u.role = 'trainer'
 WHERE ug.purpose = 'personal'
ON CONFLICT (user_id, gym_id, purpose) DO NOTHING;
