-- Outbox for atomic workout_finish → gamification processing; settings; extra missions

CREATE TABLE gamification_outbox (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    event_type VARCHAR(32) NOT NULL,
    idempotency_key VARCHAR(256) NOT NULL UNIQUE,
    payload JSONB NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    processed_at TIMESTAMPTZ
);

CREATE INDEX idx_gamification_outbox_pending ON gamification_outbox (created_at)
    WHERE processed_at IS NULL;

CREATE TABLE gamification_settings (
    key VARCHAR(64) PRIMARY KEY,
    value JSONB NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO gamification_settings (key, value)
VALUES (
    'xp_curve',
    '{"volume_divisor":50,"completion_bonus":10,"volume_max":500}'::jsonb
)
ON CONFLICT (key) DO NOTHING;

INSERT INTO mission_definitions (code, title, description, period, target_value, reward_xp)
SELECT 'gym_checkin', 'Визит в зал', 'Отметьтесь в зале сегодня', 'daily', 1, 15
WHERE NOT EXISTS (SELECT 1 FROM mission_definitions WHERE code = 'gym_checkin');

INSERT INTO mission_definitions (code, title, description, period, target_value, reward_xp)
SELECT 'group_training_register', 'Групповая тренировка', 'Запишитесь на групповую тренировку', 'weekly', 1, 20
WHERE NOT EXISTS (SELECT 1 FROM mission_definitions WHERE code = 'group_training_register');
