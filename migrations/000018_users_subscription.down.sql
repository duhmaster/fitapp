ALTER TABLE users
  DROP COLUMN IF EXISTS paid_subscriber,
  DROP COLUMN IF EXISTS subscription_expires_at;
