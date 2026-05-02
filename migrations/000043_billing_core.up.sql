CREATE TABLE IF NOT EXISTS billing_plans (
  code VARCHAR(40) PRIMARY KEY,
  title TEXT NOT NULL,
  billing_period VARCHAR(20) NOT NULL,
  price_minor BIGINT NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'RUB',
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  plan_code VARCHAR(40) NOT NULL REFERENCES billing_plans(code),
  provider VARCHAR(20) NOT NULL,
  provider_subscription_id TEXT,
  status VARCHAR(20) NOT NULL,
  auto_renew BOOLEAN NOT NULL DEFAULT TRUE,
  trial_started_at TIMESTAMPTZ,
  trial_ends_at TIMESTAMPTZ,
  current_period_start TIMESTAMPTZ NOT NULL,
  current_period_end TIMESTAMPTZ NOT NULL,
  grace_until TIMESTAMPTZ,
  canceled_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_user_status
  ON user_subscriptions(user_id, status);
CREATE INDEX IF NOT EXISTS idx_user_subscriptions_renew
  ON user_subscriptions(provider, auto_renew, current_period_end);

CREATE TABLE IF NOT EXISTS payment_methods (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider VARCHAR(20) NOT NULL,
  provider_customer_id TEXT,
  provider_method_id TEXT,
  is_default BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_payment_methods_user
  ON payment_methods(user_id);

CREATE TABLE IF NOT EXISTS billing_payments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  subscription_id UUID REFERENCES user_subscriptions(id) ON DELETE SET NULL,
  provider VARCHAR(20) NOT NULL,
  provider_payment_id TEXT NOT NULL,
  order_id TEXT NOT NULL,
  amount_minor BIGINT NOT NULL,
  currency CHAR(3) NOT NULL DEFAULT 'RUB',
  status VARCHAR(20) NOT NULL,
  failure_code TEXT,
  failure_message TEXT,
  paid_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(provider, provider_payment_id),
  UNIQUE(order_id)
);
CREATE INDEX IF NOT EXISTS idx_billing_payments_user_created
  ON billing_payments(user_id, created_at DESC);

CREATE TABLE IF NOT EXISTS billing_provider_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider VARCHAR(20) NOT NULL,
  provider_event_id TEXT,
  event_type TEXT NOT NULL,
  payload JSONB NOT NULL,
  signature_valid BOOLEAN NOT NULL DEFAULT FALSE,
  processed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(provider, provider_event_id)
);

CREATE TABLE IF NOT EXISTS billing_refunds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  payment_id UUID NOT NULL REFERENCES billing_payments(id) ON DELETE CASCADE,
  provider VARCHAR(20) NOT NULL,
  provider_refund_id TEXT,
  amount_minor BIGINT NOT NULL,
  status VARCHAR(20) NOT NULL,
  reason TEXT,
  created_by UUID,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_billing_refunds_payment
  ON billing_refunds(payment_id);

INSERT INTO billing_plans (code, title, billing_period, price_minor, currency, is_active)
VALUES
  ('free_user', 'Free User', 'month', 0, 'RUB', TRUE),
  ('premium_user', 'Premium User', 'month', 29900, 'RUB', TRUE),
  ('premium_user_yearly', 'Premium User Yearly', 'year', 249000, 'RUB', TRUE),
  ('free_coach', 'Free Coach', 'month', 0, 'RUB', TRUE),
  ('coach_pro', 'Coach Pro', 'month', 99000, 'RUB', TRUE),
  ('coach_pro_yearly', 'Coach Pro Yearly', 'year', 990000, 'RUB', TRUE)
ON CONFLICT (code) DO UPDATE
SET
  title = EXCLUDED.title,
  billing_period = EXCLUDED.billing_period,
  price_minor = EXCLUDED.price_minor,
  currency = EXCLUDED.currency,
  is_active = EXCLUDED.is_active,
  updated_at = NOW();
