package usecase

import (
	"context"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	progressdomain "github.com/fitflow/fitflow/internal/progress/domain"
)

type ProgressUseCase struct {
	weight    progressdomain.WeightTrackingRepository
	bodyFat   progressdomain.BodyFatTrackingRepository
	health    progressdomain.HealthMetricRepository
}

func NewProgressUseCase(
	weight progressdomain.WeightTrackingRepository,
	bodyFat progressdomain.BodyFatTrackingRepository,
	health progressdomain.HealthMetricRepository,
) *ProgressUseCase {
	return &ProgressUseCase{
		weight:  weight,
		bodyFat: bodyFat,
		health:  health,
	}
}

func (uc *ProgressUseCase) RecordWeight(ctx context.Context, user *authdomain.User, weightKg float64, recordedAt time.Time) (*progressdomain.WeightTracking, error) {
	return uc.weight.Create(ctx, user.ID, weightKg, recordedAt)
}

func (uc *ProgressUseCase) ListWeightHistory(ctx context.Context, user *authdomain.User, limit, offset int) ([]*progressdomain.WeightTracking, error) {
	return uc.weight.ListByUserID(ctx, user.ID, limit, offset)
}

func (uc *ProgressUseCase) RecordBodyFat(ctx context.Context, user *authdomain.User, bodyFatPct float64, recordedAt time.Time) (*progressdomain.BodyFatTracking, error) {
	return uc.bodyFat.Create(ctx, user.ID, bodyFatPct, recordedAt)
}

func (uc *ProgressUseCase) ListBodyFatHistory(ctx context.Context, user *authdomain.User, limit, offset int) ([]*progressdomain.BodyFatTracking, error) {
	return uc.bodyFat.ListByUserID(ctx, user.ID, limit, offset)
}

func (uc *ProgressUseCase) RecordHealthMetric(ctx context.Context, user *authdomain.User, metricType string, value *float64, recordedAt time.Time, source *string) (*progressdomain.HealthMetric, error) {
	return uc.health.Create(ctx, user.ID, metricType, value, recordedAt, source)
}

func (uc *ProgressUseCase) ListHealthMetrics(ctx context.Context, user *authdomain.User, metricType string, limit, offset int) ([]*progressdomain.HealthMetric, error) {
	return uc.health.ListByUserID(ctx, user.ID, metricType, limit, offset)
}
