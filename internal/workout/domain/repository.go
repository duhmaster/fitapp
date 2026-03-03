package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type ExerciseRepository interface {
	List(ctx context.Context, limit, offset int) ([]*Exercise, error)
	GetByID(ctx context.Context, id uuid.UUID) (*Exercise, error)
}

type WorkoutRepository interface {
	Create(ctx context.Context, userID uuid.UUID, templateID *uuid.UUID, scheduledAt *time.Time) (*Workout, error)
	GetByID(ctx context.Context, id uuid.UUID) (*Workout, error)
	ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*Workout, error)
	Start(ctx context.Context, id uuid.UUID, at time.Time) (*Workout, error)
	Finish(ctx context.Context, id uuid.UUID, at time.Time) (*Workout, error)
}

type WorkoutExerciseRepository interface {
	Create(ctx context.Context, workoutID, exerciseID uuid.UUID, sets, reps *int, weightKg *float64, orderIndex int) (*WorkoutExercise, error)
	ListByWorkoutID(ctx context.Context, workoutID uuid.UUID) ([]*WorkoutExercise, error)
}

type ExerciseLogRepository interface {
	Create(ctx context.Context, workoutID, exerciseID uuid.UUID, setNumber int, reps *int, weightKg *float64, restSeconds *int) (*ExerciseLog, error)
	ListByWorkoutID(ctx context.Context, workoutID uuid.UUID) ([]*ExerciseLog, error)
}
