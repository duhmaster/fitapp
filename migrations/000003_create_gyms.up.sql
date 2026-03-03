-- FITFLOW: Gym tables (search, check-in, load snapshots)

CREATE TABLE gyms (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    latitude DECIMAL(10,8),
    longitude DECIMAL(11,8),
    address TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at TIMESTAMPTZ
);

CREATE TABLE gym_check_ins (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    gym_id UUID NOT NULL REFERENCES gyms(id) ON DELETE CASCADE,
    checked_in_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE gym_load_snapshots (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    gym_id UUID NOT NULL REFERENCES gyms(id) ON DELETE CASCADE,
    load_count INT NOT NULL,
    hour_bucket TIMESTAMPTZ NOT NULL,
    UNIQUE(gym_id, hour_bucket)
);

CREATE INDEX idx_gyms_deleted_at ON gyms(deleted_at);
CREATE INDEX idx_gyms_location ON gyms(latitude, longitude) WHERE deleted_at IS NULL;
CREATE INDEX idx_gym_check_ins_user_id ON gym_check_ins(user_id);
CREATE INDEX idx_gym_check_ins_gym_id ON gym_check_ins(gym_id);
CREATE INDEX idx_gym_check_ins_checked_at ON gym_check_ins(checked_in_at DESC);
CREATE INDEX idx_gym_check_ins_user_checked ON gym_check_ins(user_id, checked_in_at DESC);
CREATE INDEX idx_gym_check_ins_gym_checked ON gym_check_ins(gym_id, checked_in_at DESC);
CREATE UNIQUE INDEX idx_gym_load_snapshots_gym_hour ON gym_load_snapshots(gym_id, hour_bucket);
