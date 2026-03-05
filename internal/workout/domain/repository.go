package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type ExerciseRepository interface {
	List(ctx context.Context, limit, offset int, filters *ExerciseFilters) ([]*Exercise, error)
	GetByID(ctx context.Context, id uuid.UUID) (*Exercise, error)
}

// ExerciseFilters holds optional filters for listing exercises.
type ExerciseFilters struct {
	MuscleGroup *string
	Tags        []string
	Difficulty  *string
}

type WorkoutRepository interface {
	Create(ctx context.Context, userID uuid.UUID, templateID *uuid.UUID, programID *uuid.UUID, scheduledAt *time.Time) (*Workout, error)
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

type ProgramRepository interface {
	List(ctx context.Context, userID *uuid.UUID, limit, offset int) ([]*Program, error)
	GetByID(ctx context.Context, id uuid.UUID) (*Program, error)
	Create(ctx context.Context, name, description string, createdBy *uuid.UUID) (*Program, error)
}

type ProgramExerciseRepository interface {
	ListByProgramID(ctx context.Context, programID uuid.UUID) ([]*ProgramExercise, error)
	Create(ctx context.Context, programID, exerciseID uuid.UUID, orderIndex int) (*ProgramExercise, error)
	CreateBatch(ctx context.Context, programID uuid.UUID, exerciseIDs []uuid.UUID, orderIndexes []int) error
}
