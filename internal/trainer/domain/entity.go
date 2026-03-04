package domain

import (
	"time"

	"github.com/google/uuid"
)

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
