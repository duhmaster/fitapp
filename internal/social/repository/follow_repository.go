package repository

import (
	"context"
	"errors"

	socialdomain "github.com/fitflow/fitflow/internal/social/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type FollowRepository struct {
	pool *pgxpool.Pool
}

func NewFollowRepository(pool *pgxpool.Pool) *FollowRepository {
	return &FollowRepository{pool: pool}
}

func (r *FollowRepository) Create(ctx context.Context, followerID, followingID uuid.UUID) (*socialdomain.Follow, error) {
	if followerID == followingID {
		return nil, socialdomain.ErrFollowSelf
	}

	query := `
		INSERT INTO follows (follower_id, following_id)
		VALUES ($1, $2)
		RETURNING follower_id, following_id, created_at
	`
	var f socialdomain.Follow
	err := r.pool.QueryRow(ctx, query, followerID, followingID).Scan(&f.FollowerID, &f.FollowingID, &f.CreatedAt)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, socialdomain.ErrAlreadyFollowing
		}
		return nil, err
	}
	return &f, nil
}

func (r *FollowRepository) Delete(ctx context.Context, followerID, followingID uuid.UUID) error {
	query := `DELETE FROM follows WHERE follower_id = $1 AND following_id = $2`
	ct, err := r.pool.Exec(ctx, query, followerID, followingID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return socialdomain.ErrNotFollowing
	}
	return nil
}

func (r *FollowRepository) IsFollowing(ctx context.Context, followerID, followingID uuid.UUID) (bool, error) {
	query := `SELECT 1 FROM follows WHERE follower_id = $1 AND following_id = $2`
	err := r.pool.QueryRow(ctx, query, followerID, followingID).Scan(new(int))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}

func (r *FollowRepository) ListFollowingIDs(ctx context.Context, followerID uuid.UUID, limit, offset int) ([]uuid.UUID, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT following_id FROM follows
		WHERE follower_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, followerID, limit, offset)
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

func (r *FollowRepository) ListFollowerIDs(ctx context.Context, followingID uuid.UUID, limit, offset int) ([]uuid.UUID, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT follower_id FROM follows
		WHERE following_id = $1
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, followingID, limit, offset)
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
