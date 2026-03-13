package domain

import (
	"time"

	"github.com/google/uuid"
)

// TrainerProfile is the public profile of a trainer (about, contacts).
type TrainerProfile struct {
	UserID    uuid.UUID
	AboutMe   string
	Contacts  string
	CreatedAt time.Time
	UpdatedAt time.Time
}

// TrainerPhoto is one photo in the trainer's gallery.
type TrainerPhoto struct {
	ID             uuid.UUID
	TrainerUserID  uuid.UUID
	Path           string
	Position       int
	CreatedAt      time.Time
}

type TrainerClient struct {
	ID        uuid.UUID
	TrainerID uuid.UUID
	ClientID  uuid.UUID
	Status    string // active, inactive
	CreatedAt time.Time
}

type TrainingProgram struct {
	ID         uuid.UUID
	TrainerID  uuid.UUID
	ClientID   uuid.UUID
	Name       string
	AssignedAt *time.Time
	CreatedAt  time.Time
}

type TrainerComment struct {
	ID        uuid.UUID
	TrainerID uuid.UUID
	ClientID  uuid.UUID
	Content   string
	CreatedAt time.Time
}
