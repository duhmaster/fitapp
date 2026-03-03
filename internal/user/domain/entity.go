package domain

import (
	"time"

	"github.com/google/uuid"
)

// Profile represents a user's profile (display name, avatar).
type Profile struct {
	ID          uuid.UUID
	UserID      uuid.UUID
	DisplayName string
	AvatarURL   string
	CreatedAt   time.Time
	UpdatedAt   time.Time
}

// Metric represents a point-in-time user metric (height, weight).
type Metric struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	HeightCm   *float64
	WeightKg   *float64
	RecordedAt time.Time
}
