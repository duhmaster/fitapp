package usecase

import (
	"context"
	"fmt"
	"io"
	"path"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/pkg/storage"
	userdomain "github.com/fitflow/fitflow/internal/user/domain"
	"github.com/google/uuid"
)

// UserUseCase handles user profile and metrics operations.
type UserUseCase struct {
	profileRepo         userdomain.ProfileRepository
	metricRepo          userdomain.MetricRepository
	bodyMeasurementRepo userdomain.BodyMeasurementRepository
	store               storage.Store
}

// NewUserUseCase creates a new UserUseCase.
func NewUserUseCase(
	profileRepo userdomain.ProfileRepository,
	metricRepo userdomain.MetricRepository,
	bodyMeasurementRepo userdomain.BodyMeasurementRepository,
	store storage.Store,
) *UserUseCase {
	return &UserUseCase{
		profileRepo:         profileRepo,
		metricRepo:         metricRepo,
		bodyMeasurementRepo: bodyMeasurementRepo,
		store:              store,
	}
}

// GetProfile returns the profile for the given user. Returns empty profile if none exists.
func (uc *UserUseCase) GetProfile(ctx context.Context, user *authdomain.User) (*userdomain.Profile, error) {
	p, err := uc.profileRepo.GetByUserID(ctx, user.ID)
	if err != nil {
		return nil, err
	}
	if p == nil {
		return &userdomain.Profile{UserID: user.ID}, nil
	}
	return p, nil
}

// UpdateProfileInput for profile updates.
type UpdateProfileInput struct {
	DisplayName string
	AvatarURL   string
}

// UpdateProfile updates the user's profile.
func (uc *UserUseCase) UpdateProfile(ctx context.Context, user *authdomain.User, in UpdateProfileInput) (*userdomain.Profile, error) {
	p, err := uc.profileRepo.GetByUserID(ctx, user.ID)
	if err != nil {
		return nil, err
	}
	if p == nil {
		p = &userdomain.Profile{UserID: user.ID}
	}
	if in.DisplayName != "" {
		p.DisplayName = in.DisplayName
	}
	if in.AvatarURL != "" {
		p.AvatarURL = in.AvatarURL
	}
	if err := uc.profileRepo.Upsert(ctx, p); err != nil {
		return nil, err
	}
	return p, nil
}

// UploadAvatar saves the avatar and returns the URL. Updates profile with new URL.
func (uc *UserUseCase) UploadAvatar(ctx context.Context, user *authdomain.User, contentType string, r io.Reader) (string, error) {
	if uc.store == nil {
		return "", fmt.Errorf("storage not configured")
	}

	ext := ".jpg"
	if contentType == "image/png" {
		ext = ".png"
	} else if contentType == "image/webp" {
		ext = ".webp"
	}

	storagePath := path.Join("avatars", user.ID.String()+ext)
	url, err := uc.store.Save(ctx, storagePath, r, contentType)
	if err != nil {
		return "", err
	}

	_, err = uc.UpdateProfile(ctx, user, UpdateProfileInput{AvatarURL: url})
	if err != nil {
		return "", err
	}
	return url, nil
}

// RecordMetricInput for recording a metric.
type RecordMetricInput struct {
	HeightCm *float64
	WeightKg *float64
	RecordedAt *time.Time
}

// RecordMetric adds a new metric entry.
func (uc *UserUseCase) RecordMetric(ctx context.Context, user *authdomain.User, in RecordMetricInput) (*userdomain.Metric, error) {
	recordedAt := time.Now()
	if in.RecordedAt != nil {
		recordedAt = *in.RecordedAt
	}
	return uc.metricRepo.Create(ctx, user.ID, in.HeightCm, in.WeightKg, recordedAt)
}

// GetLatestMetric returns the most recent metric for the user.
func (uc *UserUseCase) GetLatestMetric(ctx context.Context, user *authdomain.User) (*userdomain.Metric, error) {
	return uc.metricRepo.GetLatestByUserID(ctx, user.ID)
}

// GetMetricHistory returns metric history for the user.
func (uc *UserUseCase) GetMetricHistory(ctx context.Context, user *authdomain.User, limit int) ([]*userdomain.Metric, error) {
	return uc.metricRepo.ListByUserID(ctx, user.ID, limit)
}

// CreateBodyMeasurement adds a body measurement record.
func (uc *UserUseCase) CreateBodyMeasurement(ctx context.Context, user *authdomain.User, recordedAt time.Time, weightKg float64, bodyFatPct, heightCm *float64) (*userdomain.BodyMeasurement, error) {
	return uc.bodyMeasurementRepo.Create(ctx, user.ID, recordedAt, weightKg, bodyFatPct, heightCm)
}

// ListBodyMeasurements returns body measurements for the user.
func (uc *UserUseCase) ListBodyMeasurements(ctx context.Context, user *authdomain.User, limit int) ([]*userdomain.BodyMeasurement, error) {
	return uc.bodyMeasurementRepo.ListByUserID(ctx, user.ID, limit)
}

// UpdateBodyMeasurement updates a body measurement (must belong to user).
func (uc *UserUseCase) UpdateBodyMeasurement(ctx context.Context, user *authdomain.User, id uuid.UUID, recordedAt time.Time, weightKg float64, bodyFatPct, heightCm *float64) (*userdomain.BodyMeasurement, error) {
	m, err := uc.bodyMeasurementRepo.GetByID(ctx, id)
	if err != nil || m == nil {
		return nil, err
	}
	if m.UserID != user.ID {
		return nil, nil // forbidden
	}
	return uc.bodyMeasurementRepo.Update(ctx, id, recordedAt, weightKg, bodyFatPct, heightCm)
}

// DeleteBodyMeasurement deletes a body measurement (must belong to user).
func (uc *UserUseCase) DeleteBodyMeasurement(ctx context.Context, user *authdomain.User, id uuid.UUID) error {
	m, err := uc.bodyMeasurementRepo.GetByID(ctx, id)
	if err != nil || m == nil {
		return err
	}
	if m.UserID != user.ID {
		return nil // no-op
	}
	return uc.bodyMeasurementRepo.Delete(ctx, id)
}

