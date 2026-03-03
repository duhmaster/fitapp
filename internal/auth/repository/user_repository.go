package repository

import (
	"context"
	"errors"

	"github.com/fitflow/fitflow/internal/auth/domain"
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
		RETURNING id, email, password_hash, role, created_at, updated_at
	`
	var u domain.UserRecord
	err := r.pool.QueryRow(ctx, query, email, passwordHash, string(role)).Scan(
		&u.ID, &u.Email, &u.PasswordHash, &u.Role, &u.CreatedAt, &u.UpdatedAt,
	)
	if err != nil {
		if isUniqueViolation(err) {
			return nil, domain.ErrUserAlreadyExists
		}
		return nil, err
	}
	u.Role = domain.Role(u.Role)
	return &u, nil
}

// GetByEmail returns a user by email (excludes soft-deleted).
func (r *UserRepository) GetByEmail(ctx context.Context, email string) (*domain.UserRecord, error) {
	query := `
		SELECT id, email, password_hash, role, created_at, updated_at
		FROM users
		WHERE email = $1 AND deleted_at IS NULL
	`
	return r.scanUser(r.pool.QueryRow(ctx, query, email))
}

// GetByID returns a user by ID.
func (r *UserRepository) GetByID(ctx context.Context, id uuid.UUID) (*domain.UserRecord, error) {
	query := `
		SELECT id, email, password_hash, role, created_at, updated_at
		FROM users
		WHERE id = $1 AND deleted_at IS NULL
	`
	return r.scanUser(r.pool.QueryRow(ctx, query, id))
}

func (r *UserRepository) scanUser(row pgx.Row) (*domain.UserRecord, error) {
	var u domain.UserRecord
	var role string
	err := row.Scan(&u.ID, &u.Email, &u.PasswordHash, &role, &u.CreatedAt, &u.UpdatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrUserNotFound
		}
		return nil, err
	}
	u.Role = domain.Role(role)
	return &u, nil
}
