package domain

import (
	"time"

	"github.com/google/uuid"
)

type Gym struct {
	ID        uuid.UUID
	Name      string
	Latitude  *float64
	Longitude *float64
	Address   string
	CreatedAt time.Time
	UpdatedAt time.Time
}

type CheckIn struct {
	ID          uuid.UUID
	UserID      uuid.UUID
	GymID       uuid.UUID
	CheckedInAt time.Time
}

type LoadSnapshot struct {
	ID         uuid.UUID
	GymID      uuid.UUID
	LoadCount  int
	HourBucket time.Time
}

