-- Group trainings domain (types, templates, scheduled sessions, registrations)

-- 0) Reference types
CREATE TABLE IF NOT EXISTS group_training_types (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL UNIQUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

INSERT INTO group_training_types (name) VALUES
  ('Йога'),
  ('Пилатес'),
  ('Растяжка / Стретчинг'),
  ('Калланетика'),
  ('Бодифлекс'),
  ('Аэробика'),
  ('Степ-аэробика'),
  ('Сайклинг / Спиннинг'),
  ('Аквааэробика'),
  ('Зумба'),
  ('Танец живота'),
  ('Боди-балет'),
  ('Хип-хоп'),
  ('Табата'),
  ('HIIT / Интервальные тренировки'),
  ('CrossFit'),
  ('TRX тренировки'),
  ('Body Pump'),
  ('Функциональный тренинг'),
  ('Бег'),
  ('Велосипед'),
  ('Скандинавская ходьба'),
  ('Единоборства'),
  ('Бокс'),
  ('Кикбоксинг'),
  ('Тай-бо'),
  ('Каратэ / Тхэквондо'),
  ('ММА / Бои без правил'),
  ('Бразильское джиу-джитсу')
ON CONFLICT (name) DO NOTHING;

-- 1) Templates (soft delete)
CREATE TABLE IF NOT EXISTS group_training_templates (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(255) NOT NULL,
  description TEXT NOT NULL DEFAULT '',
  duration_minutes INT NOT NULL CHECK (duration_minutes > 0),
  equipment TEXT[] NOT NULL DEFAULT '{}',
  level_of_preparation VARCHAR(100) NOT NULL DEFAULT '',
  photo_path VARCHAR(512),
  max_people_count INT NOT NULL CHECK (max_people_count > 0),
  trainer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  group_type_id UUID NOT NULL REFERENCES group_training_types(id) ON DELETE RESTRICT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  deleted_at TIMESTAMPTZ
);

CREATE INDEX IF NOT EXISTS idx_group_training_templates_trainer_id ON group_training_templates(trainer_user_id);
CREATE INDEX IF NOT EXISTS idx_group_training_templates_group_type_id ON group_training_templates(group_type_id);
CREATE INDEX IF NOT EXISTS idx_group_training_templates_active ON group_training_templates(is_active) WHERE deleted_at IS NULL;

-- 2) Scheduled sessions
CREATE TABLE IF NOT EXISTS group_trainings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  template_id UUID NOT NULL REFERENCES group_training_templates(id) ON DELETE RESTRICT,
  scheduled_at TIMESTAMPTZ NOT NULL,
  trainer_user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  gym_id UUID NOT NULL REFERENCES gyms(id) ON DELETE RESTRICT,
  city VARCHAR(255) NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_group_trainings_trainer_scheduled ON group_trainings(trainer_user_id, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_group_trainings_city_scheduled ON group_trainings(city, scheduled_at DESC);
CREATE INDEX IF NOT EXISTS idx_group_trainings_gym_scheduled ON group_trainings(gym_id, scheduled_at DESC);

-- 3) Registrations (enrollments)
CREATE TABLE IF NOT EXISTS group_training_registrations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  group_training_id UUID NOT NULL REFERENCES group_trainings(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, group_training_id)
);

CREATE INDEX IF NOT EXISTS idx_group_training_registrations_training_id ON group_training_registrations(group_training_id);
CREATE INDEX IF NOT EXISTS idx_group_training_registrations_user_id ON group_training_registrations(user_id);

