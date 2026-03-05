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

// BodyMeasurement is a single body measurement record (weight, body fat %, height for FFMI/BMI).
type BodyMeasurement struct {
	ID          uuid.UUID
	UserID      uuid.UUID
	RecordedAt  time.Time
	WeightKg    float64
	BodyFatPct  *float64
	HeightCm    *float64
}
