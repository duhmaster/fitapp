-- FITFLOW: Trainer domain (trainer-client mapping, programs, comments)

CREATE TABLE trainer_clients (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    status VARCHAR(20) NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive')),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(trainer_id, client_id)
);

CREATE TABLE training_programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    name VARCHAR(255) NOT NULL,
    assigned_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE trainer_comments (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    trainer_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    client_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_trainer_clients_trainer_id ON trainer_clients(trainer_id);
CREATE INDEX idx_trainer_clients_client_id ON trainer_clients(client_id);
CREATE INDEX idx_training_programs_trainer_id ON training_programs(trainer_id);
CREATE INDEX idx_training_programs_client_id ON training_programs(client_id);
CREATE INDEX idx_trainer_comments_trainer_id ON trainer_comments(trainer_id);
CREATE INDEX idx_trainer_comments_client_id ON trainer_comments(client_id);
