-- System messages for app-wide announcements

CREATE TABLE IF NOT EXISTS system_messages (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    title VARCHAR(255) NOT NULL,
    body TEXT NOT NULL,
    is_active BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX IF NOT EXISTS idx_system_messages_active_created_at
    ON system_messages(is_active, created_at DESC);

