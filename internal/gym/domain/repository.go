package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type GymRepository interface {
	Create(ctx context.Context, name string, latitude, longitude *float64, address string) (*Gym, error)
	GetByID(ctx context.Context, id uuid.UUID) (*Gym, error)
	Search(ctx context.Context, query string, latitude, longitude *float64, limit, offset int) ([]*Gym, error)
	ListIDsAfter(ctx context.Context, after uuid.UUID, limit int) ([]uuid.UUID, error)
}

type CheckInRepository interface {
	Create(ctx context.Context, userID, gymID uuid.UUID, checkedInAt time.Time) (*CheckIn, error)
}

type LoadSnapshotRepository interface {
	UpsertHour(ctx context.Context, gymID uuid.UUID, hourBucket time.Time, loadCount int) error
	ListByGymID(ctx context.Context, gymID uuid.UUID, limit int) ([]*LoadSnapshot, error)
}

