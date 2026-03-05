-- Add theme and locale to users for app preferences
ALTER TABLE users
  ADD COLUMN IF NOT EXISTS theme VARCHAR(32) NOT NULL DEFAULT 'system',
  ADD COLUMN IF NOT EXISTS locale VARCHAR(16) NOT NULL DEFAULT 'en';
