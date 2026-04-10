-- Revert to single link per (user_id, gym_id): drop coaching rows if personal exists, else keep one row.
DELETE FROM user_gyms a
  USING user_gyms b
 WHERE a.user_id = b.user_id
   AND a.gym_id = b.gym_id
   AND a.purpose = 'coaching'
   AND b.purpose = 'personal';

UPDATE user_gyms SET purpose = 'personal' WHERE purpose = 'coaching';

ALTER TABLE user_gyms DROP CONSTRAINT IF EXISTS user_gyms_pkey;
ALTER TABLE user_gyms DROP COLUMN IF EXISTS purpose;
ALTER TABLE user_gyms ADD PRIMARY KEY (user_id, gym_id);

DROP INDEX IF EXISTS idx_user_gyms_user_purpose;
