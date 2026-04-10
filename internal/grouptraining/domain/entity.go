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
	PhotoPath          *string  // URL: primary / first image (join on photo_id or legacy column)
	PhotoID             *uuid.UUID
	GalleryPhotoIDs    []uuid.UUID
	GalleryPhotoURLs   []string // resolved URLs in gallery order (from DB)
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
	GymName        string // From gyms.name when joined.
	CreatedAt      time.Time
	UpdatedAt      time.Time
}

// TrainerAtGym is a trainer who conducts group trainings or personal workouts at a gym.
type TrainerAtGym struct {
	UserID      uuid.UUID
	DisplayName string
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
	GymName         string

	ParticipantsCount int
}

