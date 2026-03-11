package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type GymRepository interface {
	Create(ctx context.Context, name, city, address, contactPhone, contactURL string, latitude, longitude *float64) (*Gym, error)
	GetByID(ctx context.Context, id uuid.UUID) (*Gym, error)
	Search(ctx context.Context, query, city string, latitude, longitude *float64, limit, offset int) ([]*Gym, error)
	ListIDsAfter(ctx context.Context, after uuid.UUID, limit int) ([]uuid.UUID, error)
	Update(ctx context.Context, id uuid.UUID, name, city, address, contactPhone, contactURL string, latitude, longitude *float64) (*Gym, error)
}

type CheckInRepository interface {
	Create(ctx context.Context, userID, gymID uuid.UUID, checkedInAt time.Time) (*CheckIn, error)
}

type LoadSnapshotRepository interface {
	UpsertHour(ctx context.Context, gymID uuid.UUID, hourBucket time.Time, loadCount int) error
	ListByGymID(ctx context.Context, gymID uuid.UUID, limit int) ([]*LoadSnapshot, error)
}

// UserGymRepository links users to gyms (many-to-many).
type UserGymRepository interface {
	Add(ctx context.Context, userID, gymID uuid.UUID) error
	Remove(ctx context.Context, userID, gymID uuid.UUID) error
	ListGymIDsByUserID(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error)
	HasGym(ctx context.Context, userID, gymID uuid.UUID) (bool, error)
}

