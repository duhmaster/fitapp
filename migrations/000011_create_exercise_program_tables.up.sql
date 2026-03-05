-- FITFLOW: muscles, exercise_muscles, exercise_images, programs, program_exercises

CREATE TABLE muscles (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE exercise_muscles (
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    muscle_id UUID NOT NULL REFERENCES muscles(id) ON DELETE CASCADE,
    load_share DECIMAL(5,4) NOT NULL DEFAULT 1.0 CHECK (load_share >= 0 AND load_share <= 1),
    PRIMARY KEY (exercise_id, muscle_id)
);

CREATE TABLE exercise_images (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    url VARCHAR(1024) NOT NULL,
    order_index INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE programs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    description TEXT,
    created_by UUID REFERENCES users(id) ON DELETE SET NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE program_exercises (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    program_id UUID NOT NULL REFERENCES programs(id) ON DELETE CASCADE,
    exercise_id UUID NOT NULL REFERENCES exercises(id) ON DELETE CASCADE,
    order_index INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (program_id, exercise_id)
);

CREATE INDEX idx_exercise_muscles_exercise_id ON exercise_muscles(exercise_id);
CREATE INDEX idx_exercise_muscles_muscle_id ON exercise_muscles(muscle_id);
CREATE INDEX idx_exercise_images_exercise_id ON exercise_images(exercise_id);
CREATE INDEX idx_programs_created_by ON programs(created_by);
CREATE INDEX idx_program_exercises_program_id ON program_exercises(program_id);
CREATE INDEX idx_program_exercises_exercise_id ON program_exercises(exercise_id);
