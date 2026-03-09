package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

// UserRecord is the database representation of a user (with password hash).
type UserRecord struct {
	ID                    uuid.UUID
	Email                 string
	PasswordHash          string
	Role                  Role
	Theme                 string     // app theme: system, light, main, dark
	Locale                string     // locale code: en, ru, etc.
	PaidSubscriber        bool       // paid subscription active
	SubscriptionExpiresAt *time.Time // when paid subscription ends
	CreatedAt             time.Time
	UpdatedAt             time.Time
}

// UserRepository defines user persistence operations.
type UserRepository interface {
	Create(ctx context.Context, email, passwordHash string, role Role) (*UserRecord, error)
	GetByEmail(ctx context.Context, email string) (*UserRecord, error)
	GetByID(ctx context.Context, id uuid.UUID) (*UserRecord, error)
	UpdatePreferences(ctx context.Context, userID uuid.UUID, theme, locale string) error
	// List returns users for admin; search filters by email (empty = all).
	List(ctx context.Context, limit, offset int, search string) ([]*UserRecord, error)
	// UpdateRole updates user role (admin only).
	UpdateRole(ctx context.Context, userID uuid.UUID, role Role) error
}

// RefreshTokenRepository defines refresh token operations.
type RefreshTokenRepository interface {
	Create(ctx context.Context, userID uuid.UUID, token string, expiresAt time.Time) error
	GetByToken(ctx context.Context, token string) (*RefreshToken, error)
	DeleteByToken(ctx context.Context, token string) error
	DeleteByUserID(ctx context.Context, userID uuid.UUID) error
}
