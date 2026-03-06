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

// ListDistinctExerciseIDsForUser returns exercise IDs that appear in user's workout logs.
func (r *ExerciseLogRepository) ListDistinctExerciseIDsForUser(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	query := `
		SELECT DISTINCT el.exercise_id
		FROM exercise_logs el
		INNER JOIN workouts w ON w.id = el.workout_id
		WHERE w.user_id = $1
		ORDER BY el.exercise_id
	`
	rows, err := r.pool.Query(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

// ListVolumeHistoryByExerciseForUser returns per-workout volume (reps*weight_kg) for an exercise.
func (r *ExerciseLogRepository) ListVolumeHistoryByExerciseForUser(ctx context.Context, userID, exerciseID uuid.UUID) ([]workoutdomain.ExerciseVolumeEntry, error) {
	query := `
		SELECT w.id, COALESCE(w.started_at, w.created_at) AS workout_date,
		       COALESCE(SUM(el.reps * el.weight_kg), 0) AS volume_kg
		FROM exercise_logs el
		INNER JOIN workouts w ON w.id = el.workout_id
		WHERE w.user_id = $1 AND el.exercise_id = $2 AND el.reps > 0 AND el.weight_kg IS NOT NULL
		GROUP BY w.id, w.started_at, w.created_at
		ORDER BY COALESCE(w.started_at, w.created_at) ASC
	`
	rows, err := r.pool.Query(ctx, query, userID, exerciseID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []workoutdomain.ExerciseVolumeEntry
	for rows.Next() {
		var e workoutdomain.ExerciseVolumeEntry
		if err := rows.Scan(&e.WorkoutID, &e.WorkoutDate, &e.VolumeKg); err != nil {
			return nil, err
		}
		out = append(out, e)
	}
	return out, rows.Err()
}
