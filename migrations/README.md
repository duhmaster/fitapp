# FITFLOW Database Migrations

Migrations use [golang-migrate](https://github.com/golang-migrate/migrate) format.

## Prerequisites

Install migrate CLI:
```bash
go install -tags 'postgres' github.com/golang-migrate/migrate/v4/cmd/migrate@latest
```

## Usage

```bash
# Apply all migrations
migrate -path ./migrations -database "postgres://user:pass@localhost:5432/fitflow?sslmode=disable" up

# Rollback last migration
migrate -path ./migrations -database "postgres://user:pass@localhost:5432/fitflow?sslmode=disable" down 1

# Rollback all
migrate -path ./migrations -database "postgres://user:pass@localhost:5432/fitflow?sslmode=disable" down

# Check version
migrate -path ./migrations -database "postgres://user:pass@localhost:5432/fitflow?sslmode=disable" version
```

## Migration Order

| # | Name | Tables |
|---|------|--------|
| 1 | create_users_and_refresh_tokens | users, refresh_tokens |
| 2 | create_user_profiles_and_metrics | user_profiles, user_metrics |
| 3 | create_gyms | gyms, gym_check_ins, gym_load_snapshots |
| 4 | create_workout_tables | exercises, workout_templates, workouts, workout_exercises, exercise_logs |
| 5 | create_progress_and_health | weight_tracking, body_fat_tracking, health_metrics |
| 6 | create_social_tables | follows, friend_requests, posts, likes, comments |
| 7 | create_blog_tables | blog_posts, blog_post_photos, tags, blog_post_tags |
| 8 | create_trainer_tables | trainer_clients, training_programs, trainer_comments |
| 9 | create_notifications | notifications |
