package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// ProfileRepository defines profile persistence operations.
type ProfileRepository interface {
	GetByUserID(ctx context.Context, userID uuid.UUID) (*Profile, error)
	Upsert(ctx context.Context, profile *Profile) error
}

// MetricRepository defines user metrics persistence operations.
type MetricRepository interface {
	Create(ctx context.Context, userID uuid.UUID, heightCm, weightKg *float64, recordedAt time.Time) (*Metric, error)
	GetLatestByUserID(ctx context.Context, userID uuid.UUID) (*Metric, error)
	ListByUserID(ctx context.Context, userID uuid.UUID, limit int) ([]*Metric, error)
}
