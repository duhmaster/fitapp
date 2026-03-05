package repository

import (
	"context"
	"errors"
	"time"

	"github.com/fitflow/fitflow/internal/auth/domain"
	dbpkg "github.com/fitflow/fitflow/internal/pkg/db"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// UserRepository implements domain.UserRepository using PostgreSQL.
type UserRepository struct {
	pool *pgxpool.Pool
}

// NewUserRepository creates a new UserRepository.
func NewUserRepository(pool *pgxpool.Pool) *UserRepository {
	return &UserRepository{pool: pool}
}

// Create inserts a new user and returns it.
func (r *UserRepository) Create(ctx context.Context, email, passwordHash string, role domain.Role) (*domain.UserRecord, error) {
	query := `
		INSERT INTO users (email, password_hash, role)
		VALUES ($1, $2, $3)
		RETURNING id, email, password_hash, role, theme, locale, paid_subscriber, subscription_expires_at, created_at, updated_at
	`
	var u domain.UserRecord
	var roleStr string
	var subExp *time.Time
	err := r.pool.QueryRow(ctx, query, email, passwordHash, string(role)).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &roleStr, &u.Theme, &u.Locale, &u.PaidSubscriber, &subExp, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		if dbpkg.IsUniqueViolation(err) {
			return nil, domain.ErrUserAlreadyExists
		}
		return nil, err
	}
	u.Role = domain.Role(roleStr)
	u.SubscriptionExpiresAt = subExp
	return &u, nil
}

// GetByEmail returns a user by email (excludes soft-deleted).
func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*domain.UserRecord, error) {
	query := `
		SELECT id, email, password_hash, role, theme, locale, paid_subscriber, subscription_expires_at, created_at, updated_at
		FROM users
		WHERE email = $1 AND deleted_at IS NULL
	`
	return r.scanUser(r.pool.QueryRow(ctx, query, email))
}

// GetByID returns a user by ID (excludes soft-deleted).
func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.UserRecord, error) {
	query := `
		SELECT id, email, password_hash, role, theme, locale, paid_subscriber, subscription_expires_at, created_at, updated_at
		FROM users
		WHERE id = $1 AND deleted_at IS NULL
	`
	return r.scanUser(r.pool.QueryRow(ctx, query, id))
}

// UpdatePreferences updates theme and locale for a user.
func (r *UserRepository) UpdatePreferences(ctx context.Context, userID uuid.UUID, theme, locale string) error {
	query := `UPDATE users SET theme = $1, locale = $2, updated_at = NOW() WHERE id = $3 AND deleted_at IS NULL`
	_, err := r.pool.Exec(ctx, query, theme, locale, userID)
	return err
}

func (r *UserRepository) scanUser(row pgx.Row) (*domain.UserRecord, error) {
	var u domain.UserRecord
	var roleStr string
	var subExp *time.Time
	err := row.Scan(&u.ID, &u.Email, &u.PasswordHash, &roleStr, &u.Theme, &u.Locale, &u.PaidSubscriber, &subExp, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrUserNotFound
		}
		return nil, err
	}
	u.Role = domain.Role(roleStr)
	u.SubscriptionExpiresAt = subExp
	return &u, nil
}

