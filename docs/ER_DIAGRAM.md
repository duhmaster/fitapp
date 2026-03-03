# FITFLOW — Entity Relationship Diagram

```
┌─────────────────┐       ┌──────────────────┐
│     users       │       │  refresh_tokens  │
├─────────────────┤       ├──────────────────┤
│ id (PK)         │───┐   │ id (PK)          │
│ email           │   │   │ user_id (FK)     │◄──┘
│ password_hash   │   │   │ token            │
│ role            │   │   │ expires_at       │
│ created_at      │   │   │ created_at       │
│ updated_at      │   │   └──────────────────┘
│ deleted_at      │   │
└────────┬────────┘   │   ┌──────────────────┐
         │            │   │  user_profiles   │
         │            │   ├──────────────────┤
         │            └──►│ id (PK)          │
         │                │ user_id (FK)     │
         │                │ display_name     │
         │                │ avatar_url       │
         │                │ created_at       │
         │                │ updated_at       │
         │                └──────────────────┘
         │
         │                ┌──────────────────┐
         │                │  user_metrics    │
         │                ├──────────────────┤
         └───────────────►│ id (PK)          │
                          │ user_id (FK)     │
                          │ height_cm        │
                          │ weight_kg        │
                          │ recorded_at      │
                          └──────────────────┘
         │
         │   ┌──────────────────────────────────────────────┐
         │   │                   gyms                        │
         │   ├──────────────────────────────────────────────┤
         │   │ id (PK)                                       │
         │   │ name                                          │
         │   │ latitude                                      │
         │   │ longitude                                     │
         │   │ address                                       │
         │   │ created_at, updated_at, deleted_at            │
         │   └───────────────────────┬──────────────────────┘
         │                           │
         └──►┌──────────────────────┐│
             │   gym_check_ins      ││
             ├──────────────────────┤│
             │ id (PK)              ││
             │ user_id (FK)         │◄┘
             │ gym_id (FK)          │
             │ checked_in_at        │
             └──────────────────────┘
                          │
             ┌────────────────────────────┐
             │   gym_load_snapshots       │  (historical hourly)
             ├────────────────────────────┤
             │ id (PK)                    │
             │ gym_id (FK)                │
             │ load_count                 │
             │ hour_bucket (timestamp)    │
             └────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      WORKOUT DOMAIN                              │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│ workout_templates│     │     workouts     │     │    exercises    │
├─────────────────┤     ├──────────────────┤     ├─────────────────┤
│ id (PK)         │     │ id (PK)          │     │ id (PK)         │
│ name            │◄────│ template_id (FK) │     │ name            │
│ created_by (FK) │     │ user_id (FK)     │     │ muscle_group    │
│ created_at      │     │ scheduled_at     │     │ created_at      │
└─────────────────┘     │ started_at       │     └────────┬────────┘
                        │ finished_at      │              │
                        │ created_at       │              │
                        └────────┬─────────┘              │
                                 │                        │
                        ┌────────▼────────────────────────▼────────┐
                        │         workout_exercises                 │
                        ├──────────────────────────────────────────┤
                        │ id (PK)                                   │
                        │ workout_id (FK)                           │
                        │ exercise_id (FK)                          │
                        │ sets, reps, weight_kg                     │
                        │ order_index                              │
                        └────────────────────┬─────────────────────┘
                                             │
                        ┌────────────────────▼─────────────────────┐
                        │           exercise_logs                   │
                        ├──────────────────────────────────────────┤
                        │ id (PK)                                   │
                        │ workout_id (FK)                           │
                        │ exercise_id (FK)                          │
                        │ set_number, reps, weight_kg               │
                        │ rest_seconds                              │
                        │ logged_at                                 │
                        └──────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      PROGRESS DOMAIN                             │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐     ┌───────────────────┐
│ weight_tracking  │     │ body_fat_tracking │
├──────────────────┤     ├───────────────────┤
│ id (PK)          │     │ id (PK)           │
│ user_id (FK)     │     │ user_id (FK)      │
│ weight_kg        │     │ body_fat_pct      │
│ recorded_at      │     │ recorded_at       │
└──────────────────┘     └───────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      HEALTH DOMAIN                               │
└─────────────────────────────────────────────────────────────────┘

┌──────────────────┐
│ health_metrics   │
├──────────────────┤
│ id (PK)          │
│ user_id (FK)     │
│ metric_type      │
│ value            │
│ recorded_at      │
│ source           │
└──────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      SOCIAL DOMAIN                               │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐     ┌──────────────────┐
│     follows     │     │ friend_requests  │
├─────────────────┤     ├──────────────────┤
│ follower_id(FK) │     │ id (PK)          │
│ following_id(FK)│     │ from_user_id(FK) │
│ created_at      │     │ to_user_id (FK)  │
└─────────────────┘     │ status           │
                        │ created_at       │
                        └──────────────────┘

┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│      posts      │     │      likes       │     │    comments     │
├─────────────────┤     ├──────────────────┤     ├─────────────────┤
│ id (PK)         │◄────│ id (PK)          │     │ id (PK)         │
│ user_id (FK)    │     │ user_id (FK)     │     │ user_id (FK)    │
│ content         │     │ target_type      │◄────│ target_type     │
│ created_at      │     │ target_id        │     │ target_id       │
└─────────────────┘     └──────────────────┘     │ content         │
                                                 │ created_at      │
                                                 └─────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      BLOG DOMAIN                                 │
└─────────────────────────────────────────────────────────────────┘

┌─────────────────┐     ┌──────────────────┐     ┌─────────────────┐
│   blog_posts    │     │ blog_post_photos │     │      tags       │
├─────────────────┤     ├──────────────────┤     ├─────────────────┤
│ id (PK)         │────►│ id (PK)          │     │ id (PK)         │
│ user_id (FK)    │     │ post_id (FK)     │     │ name            │
│ title           │     │ url              │     └────────┬────────┘
│ content         │     │ sort_order       │              │
│ created_at      │     └──────────────────┘     ┌────────▼────────┐
│ updated_at      │                              │ blog_post_tags  │
└────────┬────────┘                              ├─────────────────┤
         │                                       │ post_id (FK)    │
         └──────────────────────────────────────►│ tag_id (FK)     │
                                                 └─────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                      TRAINER DOMAIN                              │
└─────────────────────────────────────────────────────────────────┘

┌────────────────────┐     ┌─────────────────────┐
│  trainer_clients   │     │  training_programs  │
├────────────────────┤     ├─────────────────────┤
│ id (PK)            │     │ id (PK)             │
│ trainer_id (FK)    │     │ trainer_id (FK)     │
│ client_id (FK)     │     │ client_id (FK)      │
│ status             │     │ name                │
│ created_at         │     │ assigned_at         │
└────────────────────┘     │ created_at          │
                           └─────────────────────┘
         │
         │         ┌─────────────────────┐
         └────────►│  trainer_comments   │
                   ├─────────────────────┤
                   │ id (PK)             │
                   │ trainer_id (FK)     │
                   │ client_id (FK)      │
                   │ content             │
                   │ created_at          │
                   └─────────────────────┘

┌─────────────────────────────────────────────────────────────────┐
│                   NOTIFICATION DOMAIN                            │
└─────────────────────────────────────────────────────────────────┘

┌────────────────────┐
│   notifications    │
├────────────────────┤
│ id (PK)            │
│ user_id (FK)       │
│ type               │
│ payload (JSONB)    │
│ read_at            │
│ created_at         │
└────────────────────┘
```

## Legend

- **PK** = Primary Key (UUID)
- **FK** = Foreign Key
- All tables use `created_at`, `updated_at` where applicable
- Soft delete via `deleted_at` on: users, gyms, blog_posts
- `role` in users: `user`, `trainer`, `admin`
