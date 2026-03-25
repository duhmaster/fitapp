package domain

import (
	"time"

	"github.com/google/uuid"
)

type GroupTrainingType struct {
	ID        uuid.UUID
	Name      string
	CreatedAt time.Time
}

type GroupTrainingTemplate struct {
	ID                  uuid.UUID
	Name                string
	Description         string
	DurationMinutes    int
	Equipment           []string
	LevelOfPreparation  string
	PhotoPath          *string  // URL: from photos table or legacy photo_path column
	PhotoID             *uuid.UUID
	MaxPeopleCount     int
	TrainerUserID       uuid.UUID
	IsActive            bool
	GroupTypeID         uuid.UUID
	CreatedAt           time.Time
	UpdatedAt           time.Time
	DeletedAt           *time.Time
}

type GroupTraining struct {
	ID             uuid.UUID
	TemplateID     uuid.UUID
	TemplateName   string // Optional, set when joined with templates table.
	ScheduledAt    time.Time
	TrainerUserID  uuid.UUID
	GymID          uuid.UUID
	City           string
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

type GroupTrainingRegistration struct {
	ID              uuid.UUID
	GroupTrainingID uuid.UUID
	UserID          uuid.UUID
	CreatedAt       time.Time
}

type ParticipantProfile struct {
	UserID      uuid.UUID
	DisplayName *string
	City        *string
	AvatarURL   *string
}

// GroupTrainingBookingItem is a rich item for "available to book" list.
type GroupTrainingBookingItem struct {
	TrainingID          uuid.UUID
	TemplateID          uuid.UUID
	TemplateName        string
	Description         string
	DurationMinutes    int
	Equipment           []string
	LevelOfPreparation  string
	PhotoPath           *string
	MaxPeopleCount     int

	GroupTypeID   uuid.UUID
	GroupTypeName string

	ScheduledAt     time.Time
	TrainerUserID   uuid.UUID
	GymID           uuid.UUID
	City            string

	ParticipantsCount int
}

