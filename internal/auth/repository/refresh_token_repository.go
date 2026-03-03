package repository

import (
	"context"
	"errors"
	"time"

	"github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// RefreshTokenRepository implements domain.RefreshTokenRepository.
type RefreshTokenRepository struct {
	pool *pgxpool.Pool
}

// NewRefreshTokenRepository creates a new RefreshTokenRepository.
func NewRefreshTokenRepository(pool *pgxpool.Pool) *RefreshTokenRepository {
	return &RefreshTokenRepository{pool: pool}
}

// Create stores a refresh token.
func (r *RefreshTokenRepository) Create(ctx context.Context, userID uuid.UUID, token string, expiresAt time.Time) error {
	query := `
		INSERT INTO refresh_tokens (user_id, token, expires_at)
		VALUES ($1, $2, $3)
	`
	_, err := r.pool.Exec(ctx, query, userID, token, expiresAt)
	return err
}

// GetByToken returns a refresh token by its value.
func (r *RefreshTokenRepository) GetByToken(ctx context.Context, token string) (*domain.RefreshToken, error) {
	query := `
		SELECT id, user_id, token, expires_at, created_at
		FROM refresh_tokens
		WHERE token = $1
	`
	var t domain.RefreshToken
	err := r.pool.QueryRow(ctx, query, token).Scan(
		&t.ID, &t.UserID, &t.Token, &t.ExpiresAt, &t.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, domain.ErrInvalidToken
		}
		return nil, err
	}
	return &t, nil
}

// DeleteByToken removes a refresh token.
func (r *RefreshTokenRepository) DeleteByToken(ctx context.Context, token string) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM refresh_tokens WHERE token = $1", token)
	return err
}

// DeleteByUserID removes all refresh tokens for a user (used on rotation).
func (r *RefreshTokenRepository) DeleteByUserID(ctx context.Context, userID uuid.UUID) error {
	_, err := r.pool.Exec(ctx, "DELETE FROM refresh_tokens WHERE user_id = $1", userID)
	return err
}
