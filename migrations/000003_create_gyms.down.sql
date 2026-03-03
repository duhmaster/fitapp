DROP INDEX IF EXISTS idx_gym_load_snapshots_gym_hour;
DROP INDEX IF EXISTS idx_gym_check_ins_gym_checked;
DROP INDEX IF EXISTS idx_gym_check_ins_user_checked;
DROP INDEX IF EXISTS idx_gym_check_ins_checked_at;
DROP INDEX IF EXISTS idx_gym_check_ins_gym_id;
DROP INDEX IF EXISTS idx_gym_check_ins_user_id;
DROP INDEX IF EXISTS idx_gyms_location;
DROP INDEX IF EXISTS idx_gyms_deleted_at;

DROP TABLE IF EXISTS gym_load_snapshots;
DROP TABLE IF EXISTS gym_check_ins;
DROP TABLE IF EXISTS gyms;
