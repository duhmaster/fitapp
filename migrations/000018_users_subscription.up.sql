-- Add paid subscriber flag and subscription expiry to users
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS paid_subscriber BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN IF NOT EXISTS subscription_expires_at TIMESTAMPTZ;
