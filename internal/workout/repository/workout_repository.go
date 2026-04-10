package repository

import (
	"context"
	"database/sql"
	"errors"
	"time"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WorkoutRepository struct {
	pool *pgxpool.Pool
}

func NewWorkoutRepository(pool *pgxpool.Pool) *WorkoutRepository {
	return &WorkoutRepository{pool: pool}
}

func (r *WorkoutRepository) Create(ctx context.Context, userID uuid.UUID, trainerID *uuid.UUID, templateID *uuid.UUID, programID *uuid.UUID, scheduledAt *time.Time, gymID *uuid.UUID) (*workoutdomain.Workout, error) {
	query := `
		INSERT INTO workouts (template_id, program_id, user_id, trainer_id, scheduled_at, gym_id)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, template_id, program_id, user_id, trainer_id, gym_id, scheduled_at, started_at, finished_at, created_at
	`
	var w workoutdomain.Workout
	err := r.pool.QueryRow(ctx, query, templateID, programID, userID, trainerID, scheduledAt, gymID).Scan(
		&w.ID, &w.TemplateID, &w.ProgramID, &w.UserID, &w.TrainerID, &w.GymID, &w.ScheduledAt, &w.StartedAt, &w.FinishedAt, &w.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &w, nil
}

func (r *WorkoutRepository) GetByID(ctx context.Context, id uuid.UUID) (*workoutdomain.Workout, error) {
	query := `
		SELECT id, template_id, program_id, user_id, trainer_id, gym_id, scheduled_at, started_at, finished_at, created_at
		FROM workouts
		WHERE id = $1
	`
	var w workoutdomain.Workout
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&w.ID, &w.TemplateID, &w.ProgramID, &w.UserID, &w.TrainerID, &w.GymID, &w.ScheduledAt, &w.StartedAt, &w.FinishedAt, &w.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, workoutdomain.ErrWorkoutNotFound
		}
		return nil, err
	}
	return &w, nil
}

func (r *WorkoutRepository) ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int, finishedFrom, finishedTo *time.Time) ([]*workoutdomain.Workout, error) {
	if limit <= 0 {
		limit = 20
	}
	maxLimit := 100
	if finishedFrom != nil || finishedTo != nil {
		maxLimit = 500
	}
	if limit > maxLimit {
		limit = maxLimit
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT w.id, w.template_id, w.program_id, w.user_id, w.trainer_id, w.gym_id, w.scheduled_at, w.started_at, w.finished_at, w.created_at, COALESCE(g.name, '')
		FROM workouts w
		LEFT JOIN gyms g ON g.id = w.gym_id
		WHERE w.user_id = $1
		  AND ($4::timestamptz IS NULL OR (w.finished_at IS NOT NULL AND w.finished_at >= $4))
		  AND ($5::timestamptz IS NULL OR (w.finished_at IS NOT NULL AND w.finished_at <= $5))
		ORDER BY w.created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, userID, limit, offset, finishedFrom, finishedTo)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*workoutdomain.Workout
	for rows.Next() {
		var w workoutdomain.Workout
		var gymName sql.NullString
		if err := rows.Scan(&w.ID, &w.TemplateID, &w.ProgramID, &w.UserID, &w.TrainerID, &w.GymID, &w.ScheduledAt, &w.StartedAt, &w.FinishedAt, &w.CreatedAt, &gymName); err != nil {
			return nil, err
		}
		if gymName.Valid && gymName.String != "" {
			s := gymName.String
			w.GymName = &s
		}
		list = append(list, &w)
	}
	return list, rows.Err()
}

func (r *WorkoutRepository) ListByTrainerID(ctx context.Context, trainerID uuid.UUID, limit, offset int) ([]*workoutdomain.Workout, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}
	query := `
		SELECT w.id, w.template_id, w.program_id, w.user_id, w.trainer_id, w.gym_id, w.scheduled_at, w.started_at, w.finished_at, w.created_at, COALESCE(g.name, '')
		FROM workouts w
		LEFT JOIN gyms g ON g.id = w.gym_id
		WHERE w.trainer_id = $1
		ORDER BY COALESCE(w.scheduled_at, w.started_at, w.created_at) DESC NULLS LAST
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, trainerID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*workoutdomain.Workout
	for rows.Next() {
		var w workoutdomain.Workout
		var gymName sql.NullString
		if err := rows.Scan(&w.ID, &w.TemplateID, &w.ProgramID, &w.UserID, &w.TrainerID, &w.GymID, &w.ScheduledAt, &w.StartedAt, &w.FinishedAt, &w.CreatedAt, &gymName); err != nil {
			return nil, err
		}
		if gymName.Valid && gymName.String != "" {
			s := gymName.String
			w.GymName = &s
		}
		list = append(list, &w)
	}
	return list, rows.Err()
}

func (r *WorkoutRepository) CountByTrainerID(ctx context.Context, trainerID uuid.UUID) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM workouts WHERE trainer_id = $1`, trainerID).Scan(&n)
	return n, err
}

func (r *WorkoutRepository) Start(ctx context.Context, id uuid.UUID, at time.Time) (*workoutdomain.Workout, error) {
	query := `
		UPDATE workouts
		SET started_at = $2
		WHERE id = $1
		RETURNING id, template_id, program_id, user_id, trainer_id, gym_id, scheduled_at, started_at, finished_at, created_at
	`
	var w workoutdomain.Workout
	err := r.pool.QueryRow(ctx, query, id, at).Scan(
		&w.ID, &w.TemplateID, &w.ProgramID, &w.UserID, &w.TrainerID, &w.GymID, &w.ScheduledAt, &w.StartedAt, &w.FinishedAt, &w.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, workoutdomain.ErrWorkoutNotFound
		}
		return nil, err
	}
	return &w, nil
}

func (r *WorkoutRepository) Finish(ctx context.Context, id uuid.UUID, at time.Time) (*workoutdomain.Workout, error) {
	return r.finishWithQuerier(ctx, r.pool, id, at)
}

func (r *WorkoutRepository) FinishTx(ctx context.Context, tx pgx.Tx, id uuid.UUID, at time.Time) (*workoutdomain.Workout, error) {
	return r.finishWithQuerier(ctx, tx, id, at)
}

type querier interface {
	QueryRow(ctx context.Context, sql string, args ...any) pgx.Row
}

func (r *WorkoutRepository) finishWithQuerier(ctx context.Context, q querier, id uuid.UUID, at time.Time) (*workoutdomain.Workout, error) {
	query := `
		UPDATE workouts
		SET finished_at = $2
		WHERE id = $1
		RETURNING id, template_id, program_id, user_id, trainer_id, gym_id, scheduled_at, started_at, finished_at, created_at
	`
	var w workoutdomain.Workout
	err := q.QueryRow(ctx, query, id, at).Scan(
		&w.ID, &w.TemplateID, &w.ProgramID, &w.UserID, &w.TrainerID, &w.GymID, &w.ScheduledAt, &w.StartedAt, &w.FinishedAt, &w.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, workoutdomain.ErrWorkoutNotFound
		}
		return nil, err
	}
	return &w, nil
}

func (r *WorkoutRepository) Delete(ctx context.Context, id uuid.UUID) error {
	_, err := r.pool.Exec(ctx, `DELETE FROM exercise_logs WHERE workout_id = $1`, id)
	if err != nil {
		return err
	}
	_, err = r.pool.Exec(ctx, `DELETE FROM workout_exercises WHERE workout_id = $1`, id)
	if err != nil {
		return err
	}
	res, err := r.pool.Exec(ctx, `DELETE FROM workouts WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return workoutdomain.ErrWorkoutNotFound
	}
	return nil
}
