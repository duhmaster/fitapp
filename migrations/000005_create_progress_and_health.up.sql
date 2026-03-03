-- FITFLOW: Progress and Health domains

CREATE TABLE weight_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    weight_kg DECIMAL(5,2) NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE body_fat_tracking (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    body_fat_pct DECIMAL(4,2) NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE health_metrics (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    metric_type VARCHAR(50) NOT NULL,
    value DECIMAL(12,4),
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    source VARCHAR(100)
);

CREATE INDEX idx_weight_tracking_user_id ON weight_tracking(user_id);
CREATE INDEX idx_weight_tracking_user_recorded ON weight_tracking(user_id, recorded_at DESC);
CREATE INDEX idx_body_fat_tracking_user_id ON body_fat_tracking(user_id);
CREATE INDEX idx_body_fat_tracking_user_recorded ON body_fat_tracking(user_id, recorded_at DESC);
CREATE INDEX idx_health_metrics_user_id ON health_metrics(user_id);
CREATE INDEX idx_health_metrics_user_type_recorded ON health_metrics(user_id, metric_type, recorded_at DESC);
