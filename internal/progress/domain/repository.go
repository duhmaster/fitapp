package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type WeightTrackingRepository interface {
	Create(ctx context.Context, userID uuid.UUID, weightKg float64, recordedAt time.Time) (*WeightTracking, error)
	ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*WeightTracking, error)
}

type BodyFatTrackingRepository interface {
	Create(ctx context.Context, userID uuid.UUID, bodyFatPct float64, recordedAt time.Time) (*BodyFatTracking, error)
	ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*BodyFatTracking, error)
}

type HealthMetricRepository interface {
	Create(ctx context.Context, userID uuid.UUID, metricType string, value *float64, recordedAt time.Time, source *string) (*HealthMetric, error)
	ListByUserID(ctx context.Context, userID uuid.UUID, metricType string, limit, offset int) ([]*HealthMetric, error)
}
