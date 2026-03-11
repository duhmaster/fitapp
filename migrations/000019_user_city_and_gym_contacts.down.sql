DROP INDEX IF EXISTS idx_user_gyms_gym_id;
DROP INDEX IF EXISTS idx_user_gyms_user_id;
DROP TABLE IF EXISTS user_gyms;
ALTER TABLE gyms DROP COLUMN IF EXISTS contact_url, DROP COLUMN IF EXISTS contact_phone, DROP COLUMN IF EXISTS city;
ALTER TABLE user_profiles DROP COLUMN IF EXISTS city;
