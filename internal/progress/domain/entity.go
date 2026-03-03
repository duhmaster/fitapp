package domain

import (
	"time"

	"github.com/google/uuid"
)

type WeightTracking struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	WeightKg   float64
	RecordedAt time.Time
}

type BodyFatTracking struct {
	ID          uuid.UUID
	UserID      uuid.UUID
	BodyFatPct  float64
	RecordedAt  time.Time
}

type HealthMetric struct {
	ID         uuid.UUID
	UserID     uuid.UUID
	MetricType string
	Value      *float64
	RecordedAt time.Time
	Source     *string
}
