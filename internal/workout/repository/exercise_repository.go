package repository

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"

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

func (r *ExerciseRepository) List(ctx context.Context, limit, offset int, filters *workoutdomain.ExerciseFilters) ([]*workoutdomain.Exercise, error) {
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
		SELECT id, name, muscle_group, COALESCE(equipment, '{}'), COALESCE(tags, '{}'), description,
		       COALESCE(instruction, '{}'), COALESCE(muscle_loads, '{}'::jsonb), formula, difficulty_level,
		       COALESCE(is_base, false), COALESCE(is_popular, false), COALESCE(is_free, true), created_at
		FROM exercises
		WHERE 1=1
	`
	args := []interface{}{}
	argNum := 1

	if filters != nil {
		if filters.MuscleGroup != nil && *filters.MuscleGroup != "" {
			query += fmt.Sprintf(" AND muscle_group = $%d", argNum)
			args = append(args, *filters.MuscleGroup)
			argNum++
		}
		if len(filters.Tags) > 0 {
			query += fmt.Sprintf(" AND tags && $%d::text[]", argNum)
			args = append(args, filters.Tags)
			argNum++
		}
		if filters.Difficulty != nil && *filters.Difficulty != "" {
			query += fmt.Sprintf(" AND difficulty_level = $%d", argNum)
			args = append(args, *filters.Difficulty)
			argNum++
		}
	}

	query += fmt.Sprintf(" ORDER BY name ASC LIMIT $%d OFFSET $%d", argNum, argNum+1)
	args = append(args, limit, offset)

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	return r.scanExercises(rows)
}

func (r *ExerciseRepository) GetByID(ctx context.Context, id uuid.UUID) (*workoutdomain.Exercise, error) {
	query := `
		SELECT id, name, muscle_group, COALESCE(equipment, '{}'), COALESCE(tags, '{}'), description,
		       COALESCE(instruction, '{}'), COALESCE(muscle_loads, '{}'::jsonb), formula, difficulty_level,
		       COALESCE(is_base, false), COALESCE(is_popular, false), COALESCE(is_free, true), created_at
		FROM exercises
		WHERE id = $1
	`
	row := r.pool.QueryRow(ctx, query, id)
	return r.scanExercise(row)
}

func (r *ExerciseRepository) scanExercises(rows pgx.Rows) ([]*workoutdomain.Exercise, error) {
	var list []*workoutdomain.Exercise
	for rows.Next() {
		var e workoutdomain.Exercise
		var equipment, tags, instruction []string
		var muscleLoads []byte
		if err := rows.Scan(&e.ID, &e.Name, &e.MuscleGroup, &equipment, &tags, &e.Description,
			&instruction, &muscleLoads, &e.Formula, &e.DifficultyLevel,
			&e.IsBase, &e.IsPopular, &e.IsFree, &e.CreatedAt); err != nil {
			return nil, err
		}
		e.Equipment = equipment
		e.Tags = tags
		e.Instruction = instruction
		if len(muscleLoads) > 0 {
			_ = json.Unmarshal(muscleLoads, &e.MuscleLoads)
		}
		if e.MuscleLoads == nil {
			e.MuscleLoads = make(map[string]float64)
		}
		list = append(list, &e)
	}
	return list, rows.Err()
}

func (r *ExerciseRepository) scanExercise(row pgx.Row) (*workoutdomain.Exercise, error) {
	var e workoutdomain.Exercise
	var equipment, tags, instruction []string
	var muscleLoads []byte
	err := row.Scan(&e.ID, &e.Name, &e.MuscleGroup, &equipment, &tags, &e.Description,
		&instruction, &muscleLoads, &e.Formula, &e.DifficultyLevel,
		&e.IsBase, &e.IsPopular, &e.IsFree, &e.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, workoutdomain.ErrExerciseNotFound
		}
		return nil, err
	}
	e.Equipment = equipment
	e.Tags = tags
	e.Instruction = instruction
	if len(muscleLoads) > 0 {
		_ = json.Unmarshal(muscleLoads, &e.MuscleLoads)
	}
	if e.MuscleLoads == nil {
		e.MuscleLoads = make(map[string]float64)
	}
	return &e, nil
}
