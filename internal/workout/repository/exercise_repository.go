package repository

import (
	"context"
	"errors"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ExerciseRepository struct {
	pool *pgxpool.Pool
}

func NewExerciseRepository(pool *pgxpool.Pool) *ExerciseRepository {
	return &ExerciseRepository{pool: pool}
}

func (r *ExerciseRepository) List(ctx context.Context, limit, offset int) ([]*workoutdomain.Exercise, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, name, muscle_group, created_at
		FROM exercises
		ORDER BY name ASC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.pool.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*workoutdomain.Exercise
	for rows.Next() {
		var e workoutdomain.Exercise
		if err := rows.Scan(&e.ID, &e.Name, &e.MuscleGroup, &e.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &e)
	}
	return list, rows.Err()
}

func (r *ExerciseRepository) GetByID(ctx context.Context, id uuid.UUID) (*workoutdomain.Exercise, error) {
	query := `
		SELECT id, name, muscle_group, created_at
		FROM exercises
		WHERE id = $1
	`
	var e workoutdomain.Exercise
	err := r.pool.QueryRow(ctx, query, id).Scan(&e.ID, &e.Name, &e.MuscleGroup, &e.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, workoutdomain.ErrExerciseNotFound
		}
		return nil, err
	}
	return &e, nil
}
