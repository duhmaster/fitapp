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
	canAccessFullAnalytics func(ctx context.Context, user *authdomain.User) (bool, error)
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
	return uc.listWeightHistoryWithEntitlement(ctx, user, limit, offset)
}

func (uc *ProgressUseCase) RecordBodyFat(ctx context.Context, user *authdomain.User, bodyFatPct float64, recordedAt time.Time) (*progressdomain.BodyFatTracking, error) {
	return uc.bodyFat.Create(ctx, user.ID, bodyFatPct, recordedAt)
}

func (uc *ProgressUseCase) ListBodyFatHistory(ctx context.Context, user *authdomain.User, limit, offset int) ([]*progressdomain.BodyFatTracking, error) {
	return uc.listBodyFatHistoryWithEntitlement(ctx, user, limit, offset)
}

func (uc *ProgressUseCase) RecordHealthMetric(ctx context.Context, user *authdomain.User, metricType string, value *float64, recordedAt time.Time, source *string) (*progressdomain.HealthMetric, error) {
	return uc.health.Create(ctx, user.ID, metricType, value, recordedAt, source)
}

func (uc *ProgressUseCase) ListHealthMetrics(ctx context.Context, user *authdomain.User, metricType string, limit, offset int) ([]*progressdomain.HealthMetric, error) {
	return uc.listHealthMetricsWithEntitlement(ctx, user, metricType, limit, offset)
}

func (uc *ProgressUseCase) SetAnalyticsAccessChecker(checker func(ctx context.Context, user *authdomain.User) (bool, error)) {
	uc.canAccessFullAnalytics = checker
}

func (uc *ProgressUseCase) listWeightHistoryWithEntitlement(ctx context.Context, user *authdomain.User, limit, offset int) ([]*progressdomain.WeightTracking, error) {
	rows, err := uc.weight.ListByUserID(ctx, user.ID, limit, offset)
	if err != nil {
		return nil, err
	}
	isPremium, err := uc.hasFullAnalytics(ctx, user)
	if err != nil {
		return nil, err
	}
	if isPremium {
		return rows, nil
	}
	if offset > 0 {
		return nil, progressdomain.ErrPremiumRequired
	}
	cutoff := time.Now().UTC().AddDate(0, 0, -14)
	filtered := make([]*progressdomain.WeightTracking, 0, len(rows))
	for _, row := range rows {
		if row.RecordedAt.After(cutoff) || row.RecordedAt.Equal(cutoff) {
			filtered = append(filtered, row)
		}
	}
	return filtered, nil
}

func (uc *ProgressUseCase) listBodyFatHistoryWithEntitlement(ctx context.Context, user *authdomain.User, limit, offset int) ([]*progressdomain.BodyFatTracking, error) {
	rows, err := uc.bodyFat.ListByUserID(ctx, user.ID, limit, offset)
	if err != nil {
		return nil, err
	}
	isPremium, err := uc.hasFullAnalytics(ctx, user)
	if err != nil {
		return nil, err
	}
	if isPremium {
		return rows, nil
	}
	if offset > 0 {
		return nil, progressdomain.ErrPremiumRequired
	}
	cutoff := time.Now().UTC().AddDate(0, 0, -14)
	filtered := make([]*progressdomain.BodyFatTracking, 0, len(rows))
	for _, row := range rows {
		if row.RecordedAt.After(cutoff) || row.RecordedAt.Equal(cutoff) {
			filtered = append(filtered, row)
		}
	}
	return filtered, nil
}

func (uc *ProgressUseCase) listHealthMetricsWithEntitlement(ctx context.Context, user *authdomain.User, metricType string, limit, offset int) ([]*progressdomain.HealthMetric, error) {
	rows, err := uc.health.ListByUserID(ctx, user.ID, metricType, limit, offset)
	if err != nil {
		return nil, err
	}
	isPremium, err := uc.hasFullAnalytics(ctx, user)
	if err != nil {
		return nil, err
	}
	if isPremium {
		return rows, nil
	}
	if offset > 0 {
		return nil, progressdomain.ErrPremiumRequired
	}
	cutoff := time.Now().UTC().AddDate(0, 0, -14)
	filtered := make([]*progressdomain.HealthMetric, 0, len(rows))
	for _, row := range rows {
		if row.RecordedAt.After(cutoff) || row.RecordedAt.Equal(cutoff) {
			filtered = append(filtered, row)
		}
	}
	return filtered, nil
}

func (uc *ProgressUseCase) hasFullAnalytics(ctx context.Context, user *authdomain.User) (bool, error) {
	if uc.canAccessFullAnalytics == nil {
		return true, nil
	}
	return uc.canAccessFullAnalytics(ctx, user)
}
