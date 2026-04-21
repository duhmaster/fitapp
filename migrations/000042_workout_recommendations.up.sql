CREATE TABLE IF NOT EXISTS workout_recommendations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  workout_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
  rec_type VARCHAR(32) NOT NULL,
  severity VARCHAR(16) NOT NULL,
  title TEXT NOT NULL,
  message TEXT NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  rule_version VARCHAR(32) NOT NULL DEFAULT 'v1',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  expires_at TIMESTAMPTZ,
  read_at TIMESTAMPTZ,
  CONSTRAINT uq_workout_rec UNIQUE (workout_id, rec_type, rule_version),
  CONSTRAINT chk_rec_type CHECK (rec_type IN (
    'load_adjust', 'sleep_recovery', 'wellbeing_alert', 'next_session', 'general_tip'
  )),
  CONSTRAINT chk_severity CHECK (severity IN ('info', 'warning', 'critical'))
);

CREATE INDEX IF NOT EXISTS idx_workout_recommendations_user_created
  ON workout_recommendations(user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_workout_recommendations_user_unread
  ON workout_recommendations(user_id, read_at, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_workout_recommendations_expires
  ON workout_recommendations(expires_at);

CREATE TABLE IF NOT EXISTS recommendation_outbox (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  workout_id UUID NOT NULL REFERENCES workouts(id) ON DELETE CASCADE,
  event_type VARCHAR(32) NOT NULL,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  processed_at TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_recommendation_outbox_pending
  ON recommendation_outbox(processed_at, created_at);
