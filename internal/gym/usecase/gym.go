package usecase

import (
	"context"
	"fmt"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	"github.com/google/uuid"
)

type GymUseCase struct {
	gyms      gymdomain.GymRepository
	checkIns  gymdomain.CheckInRepository
	snapshots gymdomain.LoadSnapshotRepository
	load      LoadService
}

func NewGymUseCase(
	gyms gymdomain.GymRepository,
	checkIns gymdomain.CheckInRepository,
	snapshots gymdomain.LoadSnapshotRepository,
	load LoadService,
) *GymUseCase {
	return &GymUseCase{gyms: gyms, checkIns: checkIns, snapshots: snapshots, load: load}
}

type CreateGymInput struct {
	Name      string
	Latitude  *float64
	Longitude *float64
	Address   string
}

func (uc *GymUseCase) CreateGym(ctx context.Context, _ *authdomain.User, in CreateGymInput) (*gymdomain.Gym, error) {
	if in.Name == "" {
		return nil, fmt.Errorf("name is required")
	}
	return uc.gyms.Create(ctx, in.Name, in.Latitude, in.Longitude, in.Address)
}

func (uc *GymUseCase) SearchGyms(ctx context.Context, query string, latitude, longitude *float64, limit, offset int) ([]*gymdomain.Gym, error) {
	return uc.gyms.Search(ctx, query, latitude, longitude, limit, offset)
}

func (uc *GymUseCase) CheckIn(ctx context.Context, user *authdomain.User, gymID uuid.UUID, at time.Time) (*gymdomain.CheckIn, int, error) {
	// Validate gym exists
	if _, err := uc.gyms.GetByID(ctx, gymID); err != nil {
		return nil, 0, err
	}

	ci, err := uc.checkIns.Create(ctx, user.ID, gymID, at)
	if err != nil {
		return nil, 0, err
	}

	if uc.load == nil {
		return ci, 0, nil
	}

	count, err := uc.load.CheckIn(ctx, gymID, user.ID, at)
	if err != nil {
		return ci, 0, err
	}

	return ci, count, nil
}

func (uc *GymUseCase) GetLoad(ctx context.Context, gymID uuid.UUID, now time.Time) (int, error) {
	if uc.load == nil {
		return 0, fmt.Errorf("load service not configured")
	}
	return uc.load.GetLoad(ctx, gymID, now)
}

func (uc *GymUseCase) GetLoadHistory(ctx context.Context, gymID uuid.UUID, limit int) ([]*gymdomain.LoadSnapshot, error) {
	return uc.snapshots.ListByGymID(ctx, gymID, limit)
}

