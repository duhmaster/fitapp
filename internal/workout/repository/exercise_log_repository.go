package repository

import (
	"context"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type ExerciseLogRepository struct {
	pool *pgxpool.Pool
}

func NewExerciseLogRepository(pool *pgxpool.Pool) *ExerciseLogRepository {
	return &ExerciseLogRepository{pool: pool}
}

func (r *ExerciseLogRepository) Create(ctx context.Context, workoutID, exerciseID uuid.UUID, setNumber int, reps *int, weightKg *float64, restSeconds *int) (*workoutdomain.ExerciseLog, error) {
	query := `
		INSERT INTO exercise_logs (workout_id, exercise_id, set_number, reps, weight_kg, rest_seconds)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, workout_id, exercise_id, set_number, reps, weight_kg, rest_seconds, logged_at
	`
	var el workoutdomain.ExerciseLog
	err := r.pool.QueryRow(ctx, query, workoutID, exerciseID, setNumber, reps, weightKg, restSeconds).Scan(
		&el.ID, &el.WorkoutID, &el.ExerciseID, &el.SetNumber, &el.Reps, &el.WeightKg, &el.RestSeconds, &el.LoggedAt,
	)
	if err != nil {
		return nil, err
	}
	return &el, nil
}

func (r *ExerciseLogRepository) ListByWorkoutID(ctx context.Context, workoutID uuid.UUID) ([]*workoutdomain.ExerciseLog, error) {
	query := `
		SELECT id, workout_id, exercise_id, set_number, reps, weight_kg, rest_seconds, logged_at
		FROM exercise_logs
		WHERE workout_id = $1
		ORDER BY logged_at ASC
	`
	rows, err := r.pool.Query(ctx, query, workoutID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*workoutdomain.ExerciseLog
	for rows.Next() {
		var el workoutdomain.ExerciseLog
		if err := rows.Scan(&el.ID, &el.WorkoutID, &el.ExerciseID, &el.SetNumber, &el.Reps, &el.WeightKg, &el.RestSeconds, &el.LoggedAt); err != nil {
			return nil, err
		}
		list = append(list, &el)
	}
	return list, rows.Err()
}
