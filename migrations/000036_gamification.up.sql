-- Gamification: profiles, XP ledger, badges, missions (MVP)

CREATE TABLE gamification_profiles (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    total_xp INT NOT NULL DEFAULT 0 CHECK (total_xp >= 0),
    current_level INT NOT NULL DEFAULT 1 CHECK (current_level >= 1),
    avatar_tier INT NOT NULL DEFAULT 0,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE xp_ledger (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    delta_xp INT NOT NULL,
    reason VARCHAR(64) NOT NULL,
    source_type VARCHAR(32),
    source_id UUID,
    idempotency_key VARCHAR(256) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_xp_ledger_user_created ON xp_ledger(user_id, created_at DESC);
CREATE INDEX idx_xp_ledger_created ON xp_ledger(created_at DESC);

CREATE TABLE badge_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(64) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    rarity VARCHAR(32) NOT NULL DEFAULT 'common',
    icon_key VARCHAR(128),
    condition_json JSONB
);

CREATE TABLE user_badges (
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    badge_id UUID NOT NULL REFERENCES badge_definitions(id) ON DELETE CASCADE,
    unlocked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    meta JSONB,
    PRIMARY KEY (user_id, badge_id)
);

CREATE INDEX idx_user_badges_user ON user_badges(user_id);

CREATE TABLE mission_definitions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(64) NOT NULL UNIQUE,
    title VARCHAR(255) NOT NULL,
    description TEXT,
    period VARCHAR(16) NOT NULL CHECK (period IN ('daily', 'weekly')),
    target_value INT NOT NULL DEFAULT 1 CHECK (target_value >= 1),
    reward_xp INT NOT NULL DEFAULT 0
);

CREATE TABLE user_mission_state (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    mission_id UUID NOT NULL REFERENCES mission_definitions(id) ON DELETE CASCADE,
    current_value INT NOT NULL DEFAULT 0,
    status VARCHAR(16) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'completed', 'claimed', 'expired')),
    window_start TIMESTAMPTZ NOT NULL,
    window_end TIMESTAMPTZ NOT NULL,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (user_id, mission_id, window_start)
);

CREATE INDEX idx_user_mission_user ON user_mission_state(user_id);
CREATE INDEX idx_user_mission_mission ON user_mission_state(mission_id);

INSERT INTO badge_definitions (code, title, description, rarity)
SELECT 'first_workout', 'Первая тренировка', 'Завершите первую тренировку', 'common'
WHERE NOT EXISTS (SELECT 1 FROM badge_definitions WHERE code = 'first_workout');

INSERT INTO badge_definitions (code, title, description, rarity)
SELECT 'trainer_scope', 'Тренер', 'Бейдж тренера (заглушка)', 'rare'
WHERE NOT EXISTS (SELECT 1 FROM badge_definitions WHERE code = 'trainer_scope');

INSERT INTO mission_definitions (code, title, description, period, target_value, reward_xp)
SELECT 'daily_workout', 'Тренировка дня', 'Завершите тренировку сегодня', 'daily', 1, 25
WHERE NOT EXISTS (SELECT 1 FROM mission_definitions WHERE code = 'daily_workout');

INSERT INTO mission_definitions (code, title, description, period, target_value, reward_xp)
SELECT 'weekly_volume', 'Неделя силы', '3 тренировки за неделю', 'weekly', 3, 100
WHERE NOT EXISTS (SELECT 1 FROM mission_definitions WHERE code = 'weekly_volume');
