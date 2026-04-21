package repository

import (
	"context"
	"database/sql"
	"errors"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type WorkoutFeedbackRepository struct {
	pool *pgxpool.Pool
}

func NewWorkoutFeedbackRepository(pool *pgxpool.Pool) *WorkoutFeedbackRepository {
	return &WorkoutFeedbackRepository{pool: pool}
}

func (r *WorkoutFeedbackRepository) Upsert(ctx context.Context, feedback *workoutdomain.WorkoutFeedback) (*workoutdomain.WorkoutFeedback, error) {
	query := `
		INSERT INTO workout_feedback (
			workout_id, user_id, session_quality, overall_wellbeing, fatigue,
			muscle_soreness, pain_discomfort, stress_level, sleep_hours, sleep_quality, note
		)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11)
		ON CONFLICT (workout_id) DO UPDATE SET
			user_id = EXCLUDED.user_id,
			session_quality = EXCLUDED.session_quality,
			overall_wellbeing = EXCLUDED.overall_wellbeing,
			fatigue = EXCLUDED.fatigue,
			muscle_soreness = EXCLUDED.muscle_soreness,
			pain_discomfort = EXCLUDED.pain_discomfort,
			stress_level = EXCLUDED.stress_level,
			sleep_hours = EXCLUDED.sleep_hours,
			sleep_quality = EXCLUDED.sleep_quality,
			note = EXCLUDED.note,
			updated_at = NOW()
		RETURNING workout_id, user_id, session_quality, overall_wellbeing, fatigue,
			muscle_soreness, pain_discomfort, stress_level, sleep_hours, sleep_quality, note, created_at, updated_at
	`
	var out workoutdomain.WorkoutFeedback
	var muscleSoreness, painDiscomfort, stressLevel, sleepQuality sql.NullInt16
	var sleepHours sql.NullFloat64
	var note sql.NullString
	err := r.pool.QueryRow(
		ctx,
		query,
		feedback.WorkoutID,
		feedback.UserID,
		feedback.SessionQuality,
		feedback.OverallWellbeing,
		feedback.Fatigue,
		feedback.MuscleSoreness,
		feedback.PainDiscomfort,
		feedback.StressLevel,
		feedback.SleepHours,
		feedback.SleepQuality,
		feedback.Note,
	).Scan(
		&out.WorkoutID,
		&out.UserID,
		&out.SessionQuality,
		&out.OverallWellbeing,
		&out.Fatigue,
		&muscleSoreness,
		&painDiscomfort,
		&stressLevel,
		&sleepHours,
		&sleepQuality,
		&note,
		&out.CreatedAt,
		&out.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	if muscleSoreness.Valid {
		v := muscleSoreness.Int16
		out.MuscleSoreness = &v
	}
	if painDiscomfort.Valid {
		v := painDiscomfort.Int16
		out.PainDiscomfort = &v
	}
	if stressLevel.Valid {
		v := stressLevel.Int16
		out.StressLevel = &v
	}
	if sleepHours.Valid {
		v := sleepHours.Float64
		out.SleepHours = &v
	}
	if sleepQuality.Valid {
		v := sleepQuality.Int16
		out.SleepQuality = &v
	}
	if note.Valid {
		v := note.String
		out.Note = &v
	}
	return &out, nil
}

func (r *WorkoutFeedbackRepository) GetByWorkoutID(ctx context.Context, workoutID uuid.UUID) (*workoutdomain.WorkoutFeedback, error) {
	query := `
		SELECT workout_id, user_id, session_quality, overall_wellbeing, fatigue,
			muscle_soreness, pain_discomfort, stress_level, sleep_hours, sleep_quality, note, created_at, updated_at
		FROM workout_feedback
		WHERE workout_id = $1
	`
	var out workoutdomain.WorkoutFeedback
	var muscleSoreness, painDiscomfort, stressLevel, sleepQuality sql.NullInt16
	var sleepHours sql.NullFloat64
	var note sql.NullString
	err := r.pool.QueryRow(ctx, query, workoutID).Scan(
		&out.WorkoutID,
		&out.UserID,
		&out.SessionQuality,
		&out.OverallWellbeing,
		&out.Fatigue,
		&muscleSoreness,
		&painDiscomfort,
		&stressLevel,
		&sleepHours,
		&sleepQuality,
		&note,
		&out.CreatedAt,
		&out.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	if muscleSoreness.Valid {
		v := muscleSoreness.Int16
		out.MuscleSoreness = &v
	}
	if painDiscomfort.Valid {
		v := painDiscomfort.Int16
		out.PainDiscomfort = &v
	}
	if stressLevel.Valid {
		v := stressLevel.Int16
		out.StressLevel = &v
	}
	if sleepHours.Valid {
		v := sleepHours.Float64
		out.SleepHours = &v
	}
	if sleepQuality.Valid {
		v := sleepQuality.Int16
		out.SleepQuality = &v
	}
	if note.Valid {
		v := note.String
		out.Note = &v
	}
	return &out, nil
}
