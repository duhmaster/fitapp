package domain

import (
	"time"

	"github.com/google/uuid"
)

// Role represents user role in the system.
type Role string

const (
	RoleUser    Role = "user"
	RoleTrainer Role = "trainer"
	RoleAdmin   Role = "admin"
)

// User represents an authenticated user (auth context).
type User struct {
	ID        uuid.UUID
	Email     string
	Role      Role
	CreatedAt time.Time
}

// RefreshToken holds refresh token metadata.
type RefreshToken struct {
	ID        uuid.UUID
	UserID    uuid.UUID
	Token     string
	ExpiresAt time.Time
	CreatedAt time.Time
}
