package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// UserRecord is the database representation of a user (with password hash).
type UserRecord struct {
	ID           uuid.UUID
	Email        string
	PasswordHash string
	Role         Role
	CreatedAt    time.Time
	UpdatedAt    time.Time
}

// UserRepository defines user persistence operations.
type UserRepository interface {
	Create(ctx context.Context, email, passwordHash string, role Role) (*UserRecord, error)
	GetByEmail(ctx context.Context, email string) (*UserRecord, error)
	GetByID(ctx context.Context, id uuid.UUID) (*UserRecord, error)
}

// RefreshTokenRepository defines refresh token operations.
type RefreshTokenRepository interface {
	Create(ctx context.Context, userID uuid.UUID, token string, expiresAt time.Time) error
	GetByToken(ctx context.Context, token string) (*RefreshToken, error)
	DeleteByToken(ctx context.Context, token string) error
	DeleteByUserID(ctx context.Context, userID uuid.UUID) error
}
