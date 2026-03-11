package repository

import (
	"context"
	"errors"

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

func (r *UserGymRepository) Add(ctx context.Context, userID, gymID uuid.UUID) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO user_gyms (user_id, gym_id) VALUES ($1, $2) ON CONFLICT (user_id, gym_id) DO NOTHING`,
		userID, gymID,
	)
	return err
}

func (r *UserGymRepository) Remove(ctx context.Context, userID, gymID uuid.UUID) error {
	ct, err := r.pool.Exec(ctx, `DELETE FROM user_gyms WHERE user_id = $1 AND gym_id = $2`, userID, gymID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return pgx.ErrNoRows
	}
	return nil
}

func (r *UserGymRepository) ListGymIDsByUserID(ctx context.Context, userID uuid.UUID) ([]uuid.UUID, error) {
	rows, err := r.pool.Query(ctx, `SELECT gym_id FROM user_gyms WHERE user_id = $1 ORDER BY created_at DESC`, userID)
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

func (r *UserGymRepository) HasGym(ctx context.Context, userID, gymID uuid.UUID) (bool, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT 1 FROM user_gyms WHERE user_id = $1 AND gym_id = $2`, userID, gymID).Scan(&n)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}
