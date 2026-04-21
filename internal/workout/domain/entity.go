package domain

import (
	"time"

	"github.com/google/uuid"
)

type Exercise struct {
	ID              uuid.UUID
	Name            string
	MuscleGroup     *string
	Equipment       []string
	Tags            []string
	Description     *string
	Instruction     []string
	MuscleLoads     map[string]float64
	Formula         *string
	DifficultyLevel *string
	IsBase          bool
	IsPopular       bool
	IsFree          bool
	CreatedAt       time.Time
}

type Program struct {
	ID          uuid.UUID
	Name        string
	Description *string
	CreatedBy   *uuid.UUID
	CreatedAt   time.Time
}

type ProgramExercise struct {
	ID         uuid.UUID
	ProgramID  uuid.UUID
	ExerciseID uuid.UUID
	OrderIndex int
	Exercise   *Exercise
}

type WorkoutTemplate struct {
	ID           uuid.UUID
	Name         string
	CreatedBy    uuid.UUID
	CreatedAt    time.Time
	DeletedAt    *time.Time
	UseRestTimer bool
	RestSeconds  int
}

type WorkoutTemplateExercise struct {
	ID            uuid.UUID
	TemplateID    uuid.UUID
	ExerciseID    uuid.UUID
	ExerciseOrder int
	Exercise      *Exercise
	Sets          []*TemplateExerciseSet
}

type TemplateExerciseSet struct {
	ID                 uuid.UUID
	TemplateExerciseID uuid.UUID
	SetOrder           int
	WeightKg           *float64
	Reps               *int
}

type Workout struct {
	ID          uuid.UUID
	TemplateID  *uuid.UUID
	ProgramID   *uuid.UUID
	UserID      uuid.UUID
	TrainerID   *uuid.UUID
	GymID       *uuid.UUID
	GymName     *string // Set on list endpoints when joined with gyms.
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
	ID          uuid.UUID
	WorkoutID   uuid.UUID
	ExerciseID  uuid.UUID
	SetNumber   int
	Reps        *int
	WeightKg    *float64
	RestSeconds *int
	LoggedAt    time.Time
}

// WorkoutFeedback is a post-workout subjective assessment.
// Core fields are mandatory; extended fields are optional.
type WorkoutFeedback struct {
	WorkoutID        uuid.UUID
	UserID           uuid.UUID
	SessionQuality   int16
	OverallWellbeing int16
	Fatigue          int16
	MuscleSoreness   *int16
	PainDiscomfort   *int16
	StressLevel      *int16
	SleepHours       *float64
	SleepQuality     *int16
	Note             *string
	CreatedAt        time.Time
	UpdatedAt        time.Time
}
