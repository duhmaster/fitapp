# FITFLOW — Database Schema Draft

## Design Decisions

- **Primary keys**: UUID (gen_random_uuid() or uuid_generate_v4())
- **Indexes**: All foreign keys, frequent filters (user_id, gym_id, created_at)
- **Soft delete**: users, gyms, blog_posts
- **Timestamps**: created_at, updated_at on all main entities

---

## Auth & User

### users
| Column        | Type         | Constraints                    |
|---------------|--------------|--------------------------------|
| id            | UUID         | PK                             |
| email         | VARCHAR(255) | UNIQUE, NOT NULL               |
| password_hash | VARCHAR(255) | NOT NULL                       |
| role          | VARCHAR(20)  | NOT NULL, CHECK (user/trainer/admin) |
| created_at    | TIMESTAMPTZ  | NOT NULL, DEFAULT NOW()        |
| updated_at    | TIMESTAMPTZ  | NOT NULL, DEFAULT NOW()        |
| deleted_at    | TIMESTAMPTZ  | NULL                           |

### refresh_tokens
| Column     | Type        | Constraints                |
|------------|-------------|----------------------------|
| id         | UUID        | PK                         |
| user_id    | UUID        | FK → users, NOT NULL       |
| token      | VARCHAR(512)| NOT NULL, UNIQUE           |
| expires_at | TIMESTAMPTZ | NOT NULL                   |
| created_at | TIMESTAMPTZ | NOT NULL, DEFAULT NOW()    |

### user_profiles
| Column       | Type         | Constraints           |
|--------------|--------------|-----------------------|
| id           | UUID         | PK                    |
| user_id      | UUID         | FK → users, UNIQUE    |
| display_name | VARCHAR(100) |                       |
| avatar_url   | VARCHAR(512) |                       |
| created_at   | TIMESTAMPTZ  | NOT NULL              |
| updated_at   | TIMESTAMPTZ  | NOT NULL              |

### user_metrics
| Column      | Type        | Constraints     |
|-------------|-------------|-----------------|
| id          | UUID        | PK              |
| user_id     | UUID        | FK → users      |
| height_cm   | DECIMAL(5,2)|                 |
| weight_kg   | DECIMAL(5,2)|                 |
| recorded_at | TIMESTAMPTZ | NOT NULL        |

---

## Gym

### gyms
| Column     | Type         | Constraints        |
|------------|--------------|--------------------|
| id         | UUID         | PK                 |
| name       | VARCHAR(255) | NOT NULL           |
| latitude   | DECIMAL(10,8)|                    |
| longitude  | DECIMAL(11,8)|                    |
| address    | TEXT         |                    |
| created_at | TIMESTAMPTZ  | NOT NULL           |
| updated_at | TIMESTAMPTZ  | NOT NULL           |
| deleted_at | TIMESTAMPTZ  | NULL               |

### gym_check_ins
| Column       | Type        | Constraints      |
|--------------|-------------|------------------|
| id           | UUID        | PK               |
| user_id      | UUID        | FK → users       |
| gym_id       | UUID        | FK → gyms        |
| checked_in_at| TIMESTAMPTZ | NOT NULL         |

### gym_load_snapshots
| Column     | Type        | Constraints   |
|------------|-------------|---------------|
| id         | UUID        | PK            |
| gym_id     | UUID        | FK → gyms     |
| load_count | INT         | NOT NULL      |
| hour_bucket| TIMESTAMPTZ | NOT NULL      |

*Unique (gym_id, hour_bucket). Populated by background worker.*

---

## Workout

### exercises
| Column       | Type         | Constraints |
|--------------|--------------|-------------|
| id           | UUID         | PK          |
| name         | VARCHAR(255) | NOT NULL    |
| muscle_group | VARCHAR(100) |             |
| created_at   | TIMESTAMPTZ  | NOT NULL    |

### workout_templates
| Column     | Type         | Constraints   |
|------------|--------------|---------------|
| id         | UUID         | PK            |
| name       | VARCHAR(255) | NOT NULL      |
| created_by | UUID         | FK → users    |
| created_at | TIMESTAMPTZ  | NOT NULL      |

### workouts
| Column      | Type        | Constraints       |
|-------------|-------------|-------------------|
| id          | UUID        | PK                |
| template_id | UUID        | FK → workout_templates (nullable) |
| user_id     | UUID        | FK → users        |
| scheduled_at| TIMESTAMPTZ |                   |
| started_at  | TIMESTAMPTZ |                   |
| finished_at | TIMESTAMPTZ |                   |
| created_at  | TIMESTAMPTZ | NOT NULL          |

### workout_exercises
| Column     | Type        | Constraints   |
|------------|-------------|---------------|
| id         | UUID        | PK            |
| workout_id | UUID        | FK → workouts |
| exercise_id| UUID        | FK → exercises|
| sets       | INT         |               |
| reps       | INT         |               |
| weight_kg  | DECIMAL(6,2)|               |
| order_index| INT         | NOT NULL      |

### exercise_logs
| Column      | Type        | Constraints   |
|-------------|-------------|---------------|
| id          | UUID        | PK            |
| workout_id  | UUID        | FK → workouts |
| exercise_id | UUID        | FK → exercises|
| set_number  | INT         | NOT NULL      |
| reps        | INT         |               |
| weight_kg   | DECIMAL(6,2)|               |
| rest_seconds| INT         |               |
| logged_at   | TIMESTAMPTZ | NOT NULL      |

---

## Progress

### weight_tracking
| Column      | Type        | Constraints |
|-------------|-------------|-------------|
| id          | UUID        | PK          |
| user_id     | UUID        | FK → users  |
| weight_kg   | DECIMAL(5,2)| NOT NULL    |
| recorded_at | TIMESTAMPTZ | NOT NULL    |

### body_fat_tracking
| Column      | Type        | Constraints |
|-------------|-------------|-------------|
| id          | UUID        | PK          |
| user_id     | UUID        | FK → users  |
| body_fat_pct| DECIMAL(4,2)| NOT NULL    |
| recorded_at | TIMESTAMPTZ | NOT NULL    |

---

## Health

### health_metrics
| Column      | Type         | Constraints |
|-------------|--------------|-------------|
| id          | UUID         | PK          |
| user_id     | UUID         | FK → users  |
| metric_type | VARCHAR(50)  | NOT NULL    |
| value       | DECIMAL(12,4)|             |
| recorded_at | TIMESTAMPTZ  | NOT NULL    |
| source      | VARCHAR(100) |             |

---

## Social

### follows
| Column       | Type        | Constraints         |
|--------------|-------------|---------------------|
| follower_id  | UUID        | FK → users, PK (part) |
| following_id | UUID        | FK → users, PK (part) |
| created_at   | TIMESTAMPTZ | NOT NULL            |

*PK (follower_id, following_id). CHECK follower_id != following_id.*

### friend_requests
| Column       | Type         | Constraints   |
|--------------|--------------|---------------|
| id           | UUID         | PK            |
| from_user_id | UUID         | FK → users    |
| to_user_id   | UUID         | FK → users    |
| status       | VARCHAR(20)  | pending/accepted/rejected |
| created_at   | TIMESTAMPTZ  | NOT NULL      |

### posts (feed)
| Column     | Type         | Constraints |
|------------|--------------|-------------|
| id         | UUID         | PK          |
| user_id    | UUID         | FK → users  |
| content    | TEXT         |             |
| created_at | TIMESTAMPTZ  | NOT NULL    |

### likes
| Column      | Type         | Constraints   |
|-------------|--------------|---------------|
| id          | UUID         | PK            |
| user_id     | UUID         | FK → users    |
| target_type | VARCHAR(50)  | post/workout/... |
| target_id   | UUID         | NOT NULL      |
| created_at  | TIMESTAMPTZ  | NOT NULL      |

*Unique (user_id, target_type, target_id)*

### comments
| Column      | Type         | Constraints   |
|-------------|--------------|---------------|
| id          | UUID         | PK            |
| user_id     | UUID         | FK → users    |
| target_type | VARCHAR(50)  | NOT NULL      |
| target_id   | UUID         | NOT NULL      |
| content     | TEXT         | NOT NULL      |
| created_at  | TIMESTAMPTZ  | NOT NULL      |

---

## Blog

### blog_posts
| Column     | Type         | Constraints |
|------------|--------------|-------------|
| id         | UUID         | PK          |
| user_id    | UUID         | FK → users  |
| title      | VARCHAR(255) | NOT NULL    |
| content    | TEXT         |             |
| created_at | TIMESTAMPTZ  | NOT NULL    |
| updated_at | TIMESTAMPTZ  | NOT NULL    |
| deleted_at | TIMESTAMPTZ  | NULL        |

### blog_post_photos
| Column    | Type         | Constraints |
|-----------|--------------|-------------|
| id        | UUID         | PK          |
| post_id   | UUID         | FK → blog_posts |
| url       | VARCHAR(512) | NOT NULL    |
| sort_order| INT          | DEFAULT 0   |

### tags
| Column | Type         | Constraints |
|--------|--------------|-------------|
| id     | UUID         | PK          |
| name   | VARCHAR(100) | NOT NULL, UNIQUE |

### blog_post_tags
| Column  | Type | Constraints          |
|---------|------|----------------------|
| post_id | UUID | FK → blog_posts, PK  |
| tag_id  | UUID | FK → tags, PK        |

---

## Trainer

### trainer_clients
| Column     | Type         | Constraints        |
|------------|--------------|--------------------|
| id         | UUID         | PK                 |
| trainer_id | UUID         | FK → users         |
| client_id  | UUID         | FK → users         |
| status     | VARCHAR(20)  | active/inactive    |
| created_at | TIMESTAMPTZ  | NOT NULL           |

*Unique (trainer_id, client_id)*

### training_programs
| Column     | Type         | Constraints |
|------------|--------------|-------------|
| id         | UUID         | PK          |
| trainer_id | UUID         | FK → users  |
| client_id  | UUID         | FK → users  |
| name       | VARCHAR(255) | NOT NULL    |
| assigned_at| TIMESTAMPTZ  |             |
| created_at | TIMESTAMPTZ  | NOT NULL    |

### trainer_comments
| Column     | Type         | Constraints |
|------------|--------------|-------------|
| id         | UUID         | PK          |
| trainer_id | UUID         | FK → users  |
| client_id  | UUID         | FK → users  |
| content    | TEXT         | NOT NULL    |
| created_at | TIMESTAMPTZ  | NOT NULL    |

---

## Notification

### notifications
| Column     | Type         | Constraints |
|------------|--------------|-------------|
| id         | UUID         | PK          |
| user_id    | UUID         | FK → users  |
| type       | VARCHAR(50)  | NOT NULL    |
| payload    | JSONB        |             |
| read_at    | TIMESTAMPTZ  | NULL        |
| created_at | TIMESTAMPTZ  | NOT NULL    |

---

## Indexes (draft)

- All FKs: `idx_<table>_<fk_column>`
- users: `idx_users_email`, `idx_users_deleted_at`
- gym_check_ins: `idx_gym_check_ins_user_checked_at`, `idx_gym_check_ins_gym_checked_at`
- gym_load_snapshots: `idx_gym_load_snapshots_gym_hour` (UNIQUE)
- workouts: `idx_workouts_user_created_at`, `idx_workouts_scheduled_at`
- exercise_logs: `idx_exercise_logs_workout`
- likes: `idx_likes_target`
- comments: `idx_comments_target`
- notifications: `idx_notifications_user_read`
- Pagination: `(user_id, created_at)` where applicable
