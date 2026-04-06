package usecase

import (
	"context"
	"errors"
	"fmt"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

type GymUseCase struct {
	gyms      gymdomain.GymRepository
	userGyms  gymdomain.UserGymRepository
	checkIns  gymdomain.CheckInRepository
	snapshots gymdomain.LoadSnapshotRepository
	load      LoadService

	gamOnCheckIn func(ctx context.Context, userID, gymID uuid.UUID) error
}

func NewGymUseCase(
	gyms gymdomain.GymRepository,
	userGyms gymdomain.UserGymRepository,
	checkIns gymdomain.CheckInRepository,
	snapshots gymdomain.LoadSnapshotRepository,
	load LoadService,
) *GymUseCase {
	return &GymUseCase{gyms: gyms, userGyms: userGyms, checkIns: checkIns, snapshots: snapshots, load: load}
}

// SetGamificationOnCheckIn is optional; called after a successful check-in DB row is created.
func (uc *GymUseCase) SetGamificationOnCheckIn(f func(ctx context.Context, userID, gymID uuid.UUID) error) {
	uc.gamOnCheckIn = f
}

type CreateGymInput struct {
	Name         string
	City         string
	Address      string
	ContactPhone string
	ContactURL   string
	Latitude     *float64
	Longitude    *float64
}

func (uc *GymUseCase) CreateGym(ctx context.Context, _ *authdomain.User, in CreateGymInput) (*gymdomain.Gym, error) {
	if in.Name == "" {
		return nil, fmt.Errorf("name is required")
	}
	return uc.gyms.Create(ctx, in.Name, in.City, in.Address, in.ContactPhone, in.ContactURL, in.Latitude, in.Longitude)
}

// ListMyGyms returns gyms linked to the user.
func (uc *GymUseCase) ListMyGyms(ctx context.Context, user *authdomain.User) ([]*gymdomain.Gym, error) {
	return uc.ListGymsByUserID(ctx, user.ID)
}

// ListGymsByUserID returns gyms linked to the given user (e.g. for public trainer profile).
func (uc *GymUseCase) ListGymsByUserID(ctx context.Context, userID uuid.UUID) ([]*gymdomain.Gym, error) {
	ids, err := uc.userGyms.ListGymIDsByUserID(ctx, userID)
	if err != nil {
		return nil, err
	}
	var gyms []*gymdomain.Gym
	for _, id := range ids {
		g, err := uc.gyms.GetByID(ctx, id)
		if err != nil {
			continue
		}
		gyms = append(gyms, g)
	}
	return gyms, nil
}

// AddGymToUser links an existing gym to the user, or creates a new gym and links it.
func (uc *GymUseCase) AddGymToUser(ctx context.Context, user *authdomain.User, gymID *uuid.UUID, orCreate *CreateGymInput) (*gymdomain.Gym, error) {
	if gymID != nil {
		if _, err := uc.gyms.GetByID(ctx, *gymID); err != nil {
			return nil, err
		}
		if err := uc.userGyms.Add(ctx, user.ID, *gymID); err != nil {
			return nil, err
		}
		return uc.gyms.GetByID(ctx, *gymID)
	}
	if orCreate == nil || orCreate.Name == "" {
		return nil, fmt.Errorf("gym_id or create payload required")
	}
	g, err := uc.gyms.Create(ctx, orCreate.Name, orCreate.City, orCreate.Address, orCreate.ContactPhone, orCreate.ContactURL, orCreate.Latitude, orCreate.Longitude)
	if err != nil {
		return nil, err
	}
	if err := uc.userGyms.Add(ctx, user.ID, g.ID); err != nil {
		return nil, err
	}
	return g, nil
}

// RemoveGymFromUser unlinks the gym from the user.
func (uc *GymUseCase) RemoveGymFromUser(ctx context.Context, user *authdomain.User, gymID uuid.UUID) error {
	err := uc.userGyms.Remove(ctx, user.ID, gymID)
	if err != nil && errors.Is(err, pgx.ErrNoRows) {
		return gymdomain.ErrGymNotFound
	}
	return err
}

// GetMyGym returns gym by ID if the user has it linked.
func (uc *GymUseCase) GetMyGym(ctx context.Context, user *authdomain.User, gymID uuid.UUID) (*gymdomain.Gym, error) {
	ok, err := uc.userGyms.HasGym(ctx, user.ID, gymID)
	if err != nil || !ok {
		return nil, gymdomain.ErrGymNotFound
	}
	return uc.gyms.GetByID(ctx, gymID)
}

func (uc *GymUseCase) SearchGyms(ctx context.Context, query, city string, latitude, longitude *float64, limit, offset int) ([]*gymdomain.Gym, error) {
	return uc.gyms.Search(ctx, query, city, latitude, longitude, limit, offset)
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

	if uc.gamOnCheckIn != nil {
		_ = uc.gamOnCheckIn(ctx, user.ID, gymID)
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

