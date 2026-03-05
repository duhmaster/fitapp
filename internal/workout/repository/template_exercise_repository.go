package repository

import (
	"context"
	"errors"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WorkoutTemplateExerciseRepository struct {
	pool *pgxpool.Pool
}

func NewWorkoutTemplateExerciseRepository(pool *pgxpool.Pool) *WorkoutTemplateExerciseRepository {
	return &WorkoutTemplateExerciseRepository{pool: pool}
}

func (r *WorkoutTemplateExerciseRepository) Create(ctx context.Context, templateID, exerciseID uuid.UUID, exerciseOrder int) (*workoutdomain.WorkoutTemplateExercise, error) {
	query := `
		INSERT INTO workout_template_exercises (template_id, exercise_id, exercise_order)
		VALUES ($1, $2, $3)
		RETURNING id, template_id, exercise_id, exercise_order
	`
	var te workoutdomain.WorkoutTemplateExercise
	err := r.pool.QueryRow(ctx, query, templateID, exerciseID, exerciseOrder).Scan(
		&te.ID, &te.TemplateID, &te.ExerciseID, &te.ExerciseOrder,
	)
	if err != nil {
		return nil, err
	}
	return &te, nil
}

func (r *WorkoutTemplateExerciseRepository) GetByID(ctx context.Context, id uuid.UUID) (*workoutdomain.WorkoutTemplateExercise, error) {
	query := `
		SELECT id, template_id, exercise_id, exercise_order
		FROM workout_template_exercises
		WHERE id = $1
	`
	var te workoutdomain.WorkoutTemplateExercise
	err := r.pool.QueryRow(ctx, query, id).Scan(&te.ID, &te.TemplateID, &te.ExerciseID, &te.ExerciseOrder)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, workoutdomain.ErrTemplateExerciseNotFound
		}
		return nil, err
	}
	return &te, nil
}

func (r *WorkoutTemplateExerciseRepository) ListByTemplateID(ctx context.Context, templateID uuid.UUID) ([]*workoutdomain.WorkoutTemplateExercise, error) {
	query := `
		SELECT id, template_id, exercise_id, exercise_order
		FROM workout_template_exercises
		WHERE template_id = $1
		ORDER BY exercise_order ASC, id ASC
	`
	rows, err := r.pool.Query(ctx, query, templateID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var list []*workoutdomain.WorkoutTemplateExercise
	for rows.Next() {
		var te workoutdomain.WorkoutTemplateExercise
		if err := rows.Scan(&te.ID, &te.TemplateID, &te.ExerciseID, &te.ExerciseOrder); err != nil {
			return nil, err
		}
		list = append(list, &te)
	}
	return list, rows.Err()
}

func (r *WorkoutTemplateExerciseRepository) UpdateOrder(ctx context.Context, id uuid.UUID, exerciseOrder int) error {
	_, err := r.pool.Exec(ctx, `UPDATE workout_template_exercises SET exercise_order = $2 WHERE id = $1`, id, exerciseOrder)
	return err
}

func (r *WorkoutTemplateExerciseRepository) Reorder(ctx context.Context, templateID uuid.UUID, orderedIDs []uuid.UUID) error {
	for i, id := range orderedIDs {
		_, err := r.pool.Exec(ctx, `UPDATE workout_template_exercises SET exercise_order = $2 WHERE id = $1 AND template_id = $3`, id, i, templateID)
		if err != nil {
			return err
		}
	}
	return nil
}

func (r *WorkoutTemplateExerciseRepository) Delete(ctx context.Context, id uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `DELETE FROM workout_template_exercises WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return workoutdomain.ErrTemplateExerciseNotFound
	}
	return nil
}
