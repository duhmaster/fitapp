-- Badges: body measurement discipline + personal records at the gym
INSERT INTO badge_definitions (code, title, description, rarity)
SELECT 'body_measurement_first', 'Первый замер', 'Зафиксировали параметры тела', 'common'
WHERE NOT EXISTS (SELECT 1 FROM badge_definitions WHERE code = 'body_measurement_first');

INSERT INTO badge_definitions (code, title, description, rarity)
SELECT 'body_measurement_10', 'Дисциплина замеров', '10 записей измерений тела', 'rare'
WHERE NOT EXISTS (SELECT 1 FROM badge_definitions WHERE code = 'body_measurement_10');

INSERT INTO badge_definitions (code, title, description, rarity)
SELECT 'pr_first', 'Новый рекорд', 'Первый личный рекорд по весу в упражнении', 'common'
WHERE NOT EXISTS (SELECT 1 FROM badge_definitions WHERE code = 'pr_first');

INSERT INTO badge_definitions (code, title, description, rarity)
SELECT 'pr_veteran', 'Охотник за рекордами', '10 тренировок с личным рекордом по весу', 'epic'
WHERE NOT EXISTS (SELECT 1 FROM badge_definitions WHERE code = 'pr_veteran');

-- Weekly mission: log body measurements (discipline, not weight direction)
INSERT INTO mission_definitions (code, title, description, period, target_value, reward_xp)
SELECT 'weekly_body_log', 'Замеры недели', 'Сделайте 2 записи измерений тела за неделю', 'weekly', 2, 40
WHERE NOT EXISTS (SELECT 1 FROM mission_definitions WHERE code = 'weekly_body_log');
