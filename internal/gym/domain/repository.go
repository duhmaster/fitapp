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

// UserGymRepository links users to gyms (many-to-many), scoped by purpose.
type UserGymRepository interface {
	Add(ctx context.Context, userID, gymID uuid.UUID, purpose UserGymPurpose) error
	Remove(ctx context.Context, userID, gymID uuid.UUID, purpose UserGymPurpose) error
	ListGymIDsByUserIDAndPurpose(ctx context.Context, userID uuid.UUID, purpose UserGymPurpose) ([]uuid.UUID, error)
	HasGymWithPurpose(ctx context.Context, userID, gymID uuid.UUID, purpose UserGymPurpose) (bool, error)
	// HasGymAnyPurpose is true if the user is linked to the gym for any purpose (e.g. open gym detail).
	HasGymAnyPurpose(ctx context.Context, userID, gymID uuid.UUID) (bool, error)
}

