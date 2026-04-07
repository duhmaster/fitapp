DELETE FROM user_mission_state WHERE mission_id IN (SELECT id FROM mission_definitions WHERE code = 'weekly_body_log');
DELETE FROM mission_definitions WHERE code = 'weekly_body_log';

DELETE FROM user_badges WHERE badge_id IN (
  SELECT id FROM badge_definitions WHERE code IN (
    'body_measurement_first', 'body_measurement_10', 'pr_first', 'pr_veteran'
  )
);
DELETE FROM badge_definitions WHERE code IN (
  'body_measurement_first', 'body_measurement_10', 'pr_first', 'pr_veteran'
);
