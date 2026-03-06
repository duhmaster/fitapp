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
	Delete(ctx context.Context, id uuid.UUID) error
}

type WorkoutExerciseRepository interface {
	Create(ctx context.Context, workoutID, exerciseID uuid.UUID, sets, reps *int, weightKg *float64, orderIndex int) (*WorkoutExercise, error)
	ListByWorkoutID(ctx context.Context, workoutID uuid.UUID) ([]*WorkoutExercise, error)
}

type ExerciseLogRepository interface {
	Create(ctx context.Context, workoutID, exerciseID uuid.UUID, setNumber int, reps *int, weightKg *float64, restSeconds *int) (*ExerciseLog, error)
	ListByWorkoutID(ctx context.Context, workoutID uuid.UUID) ([]*ExerciseLog, error)
	// ListDistinctExerciseIDsForUser returns exercise IDs that appear in user's logs.
	ListDistinctExerciseIDsForUser(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error)
	// ListVolumeHistoryByExerciseForUser returns per-workout volume for an exercise.
	ListVolumeHistoryByExerciseForUser(ctx context.Context, userID, exerciseID uuid.UUID) ([]ExerciseVolumeEntry, error)
}

// ExerciseVolumeEntry is one workout's volume for an exercise.
type ExerciseVolumeEntry struct {
	WorkoutID   uuid.UUID
	WorkoutDate time.Time
	VolumeKg    float64
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

type WorkoutTemplateRepository interface {
	Create(ctx context.Context, name string, createdBy uuid.UUID, useRestTimer bool, restSeconds int) (*WorkoutTemplate, error)
	GetByID(ctx context.Context, id uuid.UUID) (*WorkoutTemplate, error)
	ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*WorkoutTemplate, error)
	Update(ctx context.Context, id uuid.UUID, name string, useRestTimer bool, restSeconds int) (*WorkoutTemplate, error)
	SoftDelete(ctx context.Context, id uuid.UUID) error
	CountExercises(ctx context.Context, templateID uuid.UUID) (int, error)
}

type WorkoutTemplateExerciseRepository interface {
	Create(ctx context.Context, templateID, exerciseID uuid.UUID, exerciseOrder int) (*WorkoutTemplateExercise, error)
	GetByID(ctx context.Context, id uuid.UUID) (*WorkoutTemplateExercise, error)
	ListByTemplateID(ctx context.Context, templateID uuid.UUID) ([]*WorkoutTemplateExercise, error)
	UpdateOrder(ctx context.Context, id uuid.UUID, exerciseOrder int) error
	Reorder(ctx context.Context, templateID uuid.UUID, orderedIDs []uuid.UUID) error
	Delete(ctx context.Context, id uuid.UUID) error
}

type TemplateExerciseSetRepository interface {
	Create(ctx context.Context, templateExerciseID uuid.UUID, setOrder int, weightKg *float64, reps *int) (*TemplateExerciseSet, error)
	ListByTemplateExerciseID(ctx context.Context, templateExerciseID uuid.UUID) ([]*TemplateExerciseSet, error)
	Delete(ctx context.Context, id uuid.UUID) error
	DeleteByIDAndTemplateExerciseID(ctx context.Context, setID, templateExerciseID uuid.UUID) error
	DeleteByTemplateExerciseID(ctx context.Context, templateExerciseID uuid.UUID) error
}
