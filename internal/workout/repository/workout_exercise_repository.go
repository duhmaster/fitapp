package repository

import (
	"context"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WorkoutExerciseRepository struct {
	pool *pgxpool.Pool
}

func NewWorkoutExerciseRepository(pool *pgxpool.Pool) *WorkoutExerciseRepository {
	return &WorkoutExerciseRepository{pool: pool}
}

func (r *WorkoutExerciseRepository) Create(ctx context.Context, workoutID, exerciseID uuid.UUID, sets, reps *int, weightKg *float64, orderIndex int) (*workoutdomain.WorkoutExercise, error) {
	query := `
		INSERT INTO workout_exercises (workout_id, exercise_id, sets, reps, weight_kg, order_index)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, workout_id, exercise_id, sets, reps, weight_kg, order_index
	`
	var we workoutdomain.WorkoutExercise
	err := r.pool.QueryRow(ctx, query, workoutID, exerciseID, sets, reps, weightKg, orderIndex).Scan(
		&we.ID, &we.WorkoutID, &we.ExerciseID, &we.Sets, &we.Reps, &we.WeightKg, &we.OrderIndex,
	)
	if err != nil {
		return nil, err
	}
	return &we, nil
}

func (r *WorkoutExerciseRepository) ListByWorkoutID(ctx context.Context, workoutID uuid.UUID) ([]*workoutdomain.WorkoutExercise, error) {
	query := `
		SELECT id, workout_id, exercise_id, sets, reps, weight_kg, order_index
		FROM workout_exercises
		WHERE workout_id = $1
		ORDER BY order_index ASC, id ASC
	`
	rows, err := r.pool.Query(ctx, query, workoutID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*workoutdomain.WorkoutExercise
	for rows.Next() {
		var we workoutdomain.WorkoutExercise
		if err := rows.Scan(&we.ID, &we.WorkoutID, &we.ExerciseID, &we.Sets, &we.Reps, &we.WeightKg, &we.OrderIndex); err != nil {
			return nil, err
		}
		list = append(list, &we)
	}
	return list, rows.Err()
}
