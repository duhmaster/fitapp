-- Per-user gamification UI flags (synced with mobile settings); default ON for everyone.

CREATE TABLE user_gamification_prefs (
    user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    xp_enabled BOOLEAN NOT NULL DEFAULT true,
    badges_enabled BOOLEAN NOT NULL DEFAULT true,
    leaderboard_enabled BOOLEAN NOT NULL DEFAULT true,
    trainer_ranking_enabled BOOLEAN NOT NULL DEFAULT true,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO user_gamification_prefs (user_id, xp_enabled, badges_enabled, leaderboard_enabled, trainer_ranking_enabled)
SELECT id, true, true, true, true FROM users WHERE deleted_at IS NULL
ON CONFLICT (user_id) DO NOTHING;

CREATE OR REPLACE FUNCTION ensure_user_gamification_prefs()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO user_gamification_prefs (user_id) VALUES (NEW.id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_users_gamification_prefs ON users;
CREATE TRIGGER trg_users_gamification_prefs
    AFTER INSERT ON users
    FOR EACH ROW EXECUTE FUNCTION ensure_user_gamification_prefs();
