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
	if limit > 2000 {
		limit = 2000
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

func (r *ExerciseRepository) GetByName(ctx context.Context, name string) (*workoutdomain.Exercise, error) {
	query := `
		SELECT id, name, muscle_group, COALESCE(equipment, '{}'), COALESCE(tags, '{}'), description,
		       COALESCE(instruction, '{}'), COALESCE(muscle_loads, '{}'::jsonb), formula, difficulty_level,
		       COALESCE(is_base, false), COALESCE(is_popular, false), COALESCE(is_free, true), created_at
		FROM exercises
		WHERE LOWER(name) = LOWER($1)
		LIMIT 1
	`
	row := r.pool.QueryRow(ctx, query, name)
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

func (r *ExerciseRepository) Create(ctx context.Context, e *workoutdomain.Exercise) (*workoutdomain.Exercise, error) {
	muscleLoadsJSON := []byte("{}")
	if len(e.MuscleLoads) > 0 {
		muscleLoadsJSON, _ = json.Marshal(e.MuscleLoads)
	}
	query := `
		INSERT INTO exercises (name, muscle_group, equipment, tags, description, instruction, muscle_loads, formula, difficulty_level, is_base, is_popular, is_free)
		VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12)
		RETURNING id, name, muscle_group, COALESCE(equipment, '{}'), COALESCE(tags, '{}'), description,
		       COALESCE(instruction, '{}'), COALESCE(muscle_loads, '{}'::jsonb), formula, difficulty_level,
		       COALESCE(is_base, false), COALESCE(is_popular, false), COALESCE(is_free, true), created_at
	`
	row := r.pool.QueryRow(ctx, query,
		e.Name, e.MuscleGroup, e.Equipment, e.Tags, e.Description, e.Instruction, muscleLoadsJSON,
		e.Formula, e.DifficultyLevel, e.IsBase, e.IsPopular, e.IsFree,
	)
	return r.scanExercise(row)
}

func (r *ExerciseRepository) Update(ctx context.Context, e *workoutdomain.Exercise) (*workoutdomain.Exercise, error) {
	muscleLoadsJSON := []byte("{}")
	if len(e.MuscleLoads) > 0 {
		muscleLoadsJSON, _ = json.Marshal(e.MuscleLoads)
	}
	query := `
		UPDATE exercises
		SET name = $2, muscle_group = $3, equipment = $4, tags = $5, description = $6, instruction = $7, muscle_loads = $8, formula = $9, difficulty_level = $10, is_base = $11, is_popular = $12, is_free = $13
		WHERE id = $1
		RETURNING id, name, muscle_group, COALESCE(equipment, '{}'), COALESCE(tags, '{}'), description,
		       COALESCE(instruction, '{}'), COALESCE(muscle_loads, '{}'::jsonb), formula, difficulty_level,
		       COALESCE(is_base, false), COALESCE(is_popular, false), COALESCE(is_free, true), created_at
	`
	row := r.pool.QueryRow(ctx, query,
		e.ID, e.Name, e.MuscleGroup, e.Equipment, e.Tags, e.Description, e.Instruction, muscleLoadsJSON,
		e.Formula, e.DifficultyLevel, e.IsBase, e.IsPopular, e.IsFree,
	)
	return r.scanExercise(row)
}

func (r *ExerciseRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM exercises WHERE id = $1`
	ct, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return workoutdomain.ErrExerciseNotFound
	}
	return nil
}
