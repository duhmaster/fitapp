package repository

import (
	"context"
	"errors"
	"time"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WorkoutTemplateRepository struct {
	pool *pgxpool.Pool
}

func NewWorkoutTemplateRepository(pool *pgxpool.Pool) *WorkoutTemplateRepository {
	return &WorkoutTemplateRepository{pool: pool}
}

func (r *WorkoutTemplateRepository) Create(ctx context.Context, name string, createdBy uuid.UUID, useRestTimer bool, restSeconds int) (*workoutdomain.WorkoutTemplate, error) {
	query := `
		INSERT INTO workout_templates (name, created_by, use_rest_timer, rest_seconds)
		VALUES ($1, $2, $3, $4)
		RETURNING id, name, created_by, created_at, deleted_at, use_rest_timer, rest_seconds
	`
	var t workoutdomain.WorkoutTemplate
	var createdAt time.Time
	var deletedAt *time.Time
	err := r.pool.QueryRow(ctx, query, name, createdBy, useRestTimer, restSeconds).Scan(
		&t.ID, &t.Name, &t.CreatedBy, &createdAt, &deletedAt, &t.UseRestTimer, &t.RestSeconds,
	)
	if err != nil {
		return nil, err
	}
	t.CreatedAt = createdAt
	t.DeletedAt = deletedAt
	return &t, nil
}

func (r *WorkoutTemplateRepository) GetByID(ctx context.Context, id uuid.UUID) (*workoutdomain.WorkoutTemplate, error) {
	query := `
		SELECT id, name, created_by, created_at, deleted_at, use_rest_timer, rest_seconds
		FROM workout_templates
		WHERE id = $1 AND deleted_at IS NULL
	`
	var t workoutdomain.WorkoutTemplate
	var createdAt time.Time
	err := r.pool.QueryRow(ctx, query, id).Scan(&t.ID, &t.Name, &t.CreatedBy, &createdAt, &t.DeletedAt, &t.UseRestTimer, &t.RestSeconds)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, workoutdomain.ErrTemplateNotFound
		}
		return nil, err
	}
	t.CreatedAt = createdAt
	return &t, nil
}

func (r *WorkoutTemplateRepository) ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*workoutdomain.WorkoutTemplate, error) {
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
		SELECT id, name, created_by, created_at, deleted_at, use_rest_timer, rest_seconds
		FROM workout_templates
		WHERE created_by = $1 AND deleted_at IS NULL
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*workoutdomain.WorkoutTemplate
	for rows.Next() {
		var t workoutdomain.WorkoutTemplate
		var createdAt time.Time
		if err := rows.Scan(&t.ID, &t.Name, &t.CreatedBy, &createdAt, &t.DeletedAt, &t.UseRestTimer, &t.RestSeconds); err != nil {
			return nil, err
		}
		t.CreatedAt = createdAt
		list = append(list, &t)
	}
	return list, rows.Err()
}

func (r *WorkoutTemplateRepository) Update(ctx context.Context, id uuid.UUID, name string, useRestTimer bool, restSeconds int) (*workoutdomain.WorkoutTemplate, error) {
	query := `
		UPDATE workout_templates
		SET name = $2, use_rest_timer = $3, rest_seconds = $4
		WHERE id = $1 AND deleted_at IS NULL
		RETURNING id, name, created_by, created_at, deleted_at, use_rest_timer, rest_seconds
	`
	var t workoutdomain.WorkoutTemplate
	var createdAt time.Time
	err := r.pool.QueryRow(ctx, query, id, name, useRestTimer, restSeconds).Scan(
		&t.ID, &t.Name, &t.CreatedBy, &createdAt, &t.DeletedAt, &t.UseRestTimer, &t.RestSeconds,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, workoutdomain.ErrTemplateNotFound
		}
		return nil, err
	}
	t.CreatedAt = createdAt
	return &t, nil
}

func (r *WorkoutTemplateRepository) SoftDelete(ctx context.Context, id uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `UPDATE workout_templates SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL`, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return workoutdomain.ErrTemplateNotFound
	}
	return nil
}

func (r *WorkoutTemplateRepository) CountExercises(ctx context.Context, templateID uuid.UUID) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM workout_template_exercises WHERE template_id = $1`, templateID).Scan(&n)
	return n, err
}
