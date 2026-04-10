package repository

import (
	"context"
	"errors"

	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserGymRepository struct {
	pool *pgxpool.Pool
}

func NewUserGymRepository(pool *pgxpool.Pool) *UserGymRepository {
	return &UserGymRepository{pool: pool}
}

func (r *UserGymRepository) Add(ctx context.Context, userID, gymID uuid.UUID, purpose gymdomain.UserGymPurpose) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_gyms (user_id, gym_id, purpose) VALUES ($1, $2, $3) ON CONFLICT (user_id, gym_id, purpose) DO NOTHING`,
		userID, gymID, string(purpose),
	)
	return err
}

func (r *UserGymRepository) Remove(ctx context.Context, userID, gymID uuid.UUID, purpose gymdomain.UserGymPurpose) error {
	ct, err := r.pool.Exec(ctx,
		`DELETE FROM user_gyms WHERE user_id = $1 AND gym_id = $2 AND purpose = $3`,
		userID, gymID, string(purpose),
	)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *UserGymRepository) ListGymIDsByUserIDAndPurpose(ctx context.Context, userID uuid.UUID, purpose gymdomain.UserGymPurpose) ([]uuid.UUID, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT gym_id FROM user_gyms WHERE user_id = $1 AND purpose = $2 ORDER BY created_at DESC`,
		userID, string(purpose),
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var ids []uuid.UUID
	for rows.Next() {
		var id uuid.UUID
		if err := rows.Scan(&id); err != nil {
			return nil, err
		}
		ids = append(ids, id)
	}
	return ids, rows.Err()
}

func (r *UserGymRepository) HasGymWithPurpose(ctx context.Context, userID, gymID uuid.UUID, purpose gymdomain.UserGymPurpose) (bool, error) {
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT 1 FROM user_gyms WHERE user_id = $1 AND gym_id = $2 AND purpose = $3`,
		userID, gymID, string(purpose),
	).Scan(&n)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (r *UserGymRepository) HasGymAnyPurpose(ctx context.Context, userID, gymID uuid.UUID) (bool, error) {
	var n int
	err := r.pool.QueryRow(ctx,
		`SELECT 1 FROM user_gyms WHERE user_id = $1 AND gym_id = $2 LIMIT 1`,
		userID, gymID,
	).Scan(&n)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}
