DELETE FROM mission_definitions WHERE code IN ('gym_checkin', 'group_training_register');
DROP TABLE IF EXISTS gamification_settings;
DROP TABLE IF EXISTS gamification_outbox;
