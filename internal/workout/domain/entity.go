package domain

import (
	"time"

	"github.com/google/uuid"
)

type Exercise struct {
	ID          uuid.UUID
	Name        string
	MuscleGroup *string
	CreatedAt   time.Time
}

type WorkoutTemplate struct {
	ID        uuid.UUID
	Name      string
	CreatedBy uuid.UUID
	CreatedAt time.Time
}

type Workout struct {
	ID          uuid.UUID
	TemplateID  *uuid.UUID
	UserID      uuid.UUID
	ScheduledAt *time.Time
	StartedAt   *time.Time
	FinishedAt  *time.Time
	CreatedAt   time.Time
}

type WorkoutExercise struct {
	ID         uuid.UUID
	WorkoutID  uuid.UUID
	ExerciseID uuid.UUID
	Sets       *int
	Reps       *int
	WeightKg   *float64
	OrderIndex int
}

type ExerciseLog struct {
	ID         uuid.UUID
	WorkoutID  uuid.UUID
	ExerciseID uuid.UUID
	SetNumber  int
	Reps       *int
	WeightKg   *float64
	RestSeconds *int
	LoggedAt   time.Time
}
