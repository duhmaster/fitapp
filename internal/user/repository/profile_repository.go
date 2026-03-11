package repository

import (
	"context"
	"errors"

	"github.com/fitflow/fitflow/internal/user/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ProfileRepository implements domain.ProfileRepository.
type ProfileRepository struct {
	pool *pgxpool.Pool
}

// NewProfileRepository creates a new ProfileRepository.
func NewProfileRepository(pool *pgxpool.Pool) *ProfileRepository {
	return &ProfileRepository{pool: pool}
}

// GetByUserID returns the profile for a user, or nil if not found.
func (r *ProfileRepository) GetByUserID(ctx context.Context, userID uuid.UUID) (*domain.Profile, error) {
	query := `
		SELECT id, user_id, display_name, avatar_url, COALESCE(city, ''), created_at, updated_at
		FROM user_profiles
		WHERE user_id = $1
	`
	var p domain.Profile
	err := r.pool.QueryRow(ctx, query, userID).Scan(
		&p.ID, &p.UserID, &p.DisplayName, &p.AvatarURL, &p.City, &p.CreatedAt, &p.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, nil
		}
		return nil, err
	}
	return &p, nil
}

// Upsert creates or updates a profile.
func (r *ProfileRepository) Upsert(ctx context.Context, profile *domain.Profile) error {
	query := `
		INSERT INTO user_profiles (user_id, display_name, avatar_url, city, updated_at)
		VALUES ($1, $2, $3, $4, NOW())
		ON CONFLICT (user_id) DO UPDATE SET
			display_name = EXCLUDED.display_name,
			avatar_url = EXCLUDED.avatar_url,
			city = EXCLUDED.city,
			updated_at = NOW()
		RETURNING id, created_at, updated_at
	`
	return r.pool.QueryRow(ctx, query, profile.UserID, profile.DisplayName, profile.AvatarURL, profile.City).
		Scan(&profile.ID, &profile.CreatedAt, &profile.UpdatedAt)
}
