DROP INDEX IF EXISTS idx_health_metrics_user_type_recorded;
DROP INDEX IF EXISTS idx_health_metrics_user_id;
DROP INDEX IF EXISTS idx_body_fat_tracking_user_recorded;
DROP INDEX IF EXISTS idx_body_fat_tracking_user_id;
DROP INDEX IF EXISTS idx_weight_tracking_user_recorded;
DROP INDEX IF EXISTS idx_weight_tracking_user_id;

DROP TABLE IF EXISTS health_metrics;
DROP TABLE IF EXISTS body_fat_tracking;
DROP TABLE IF EXISTS weight_tracking;
