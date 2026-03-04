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

type LikeRepository struct {
	pool *pgxpool.Pool
}

func NewLikeRepository(pool *pgxpool.Pool) *LikeRepository {
	return &LikeRepository{pool: pool}
}

func (r *LikeRepository) Create(ctx context.Context, userID uuid.UUID, targetType string, targetID uuid.UUID) (*socialdomain.Like, error) {
	query := `
		INSERT INTO likes (user_id, target_type, target_id)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, target_type, target_id, created_at
	`
	var l socialdomain.Like
	err := r.pool.QueryRow(ctx, query, userID, targetType, targetID).Scan(
		&l.ID, &l.UserID, &l.TargetType, &l.TargetID, &l.CreatedAt,
	)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, socialdomain.ErrAlreadyLiked
		}
		return nil, err
	}
	return &l, nil
}

func (r *LikeRepository) Delete(ctx context.Context, userID uuid.UUID, targetType string, targetID uuid.UUID) error {
	query := `DELETE FROM likes WHERE user_id = $1 AND target_type = $2 AND target_id = $3`
	ct, err := r.pool.Exec(ctx, query, userID, targetType, targetID)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return socialdomain.ErrNotLiked
	}
	return nil
}

func (r *LikeRepository) CountByTarget(ctx context.Context, targetType string, targetID uuid.UUID) (int, error) {
	query := `SELECT COUNT(*) FROM likes WHERE target_type = $1 AND target_id = $2`
	var count int
	err := r.pool.QueryRow(ctx, query, targetType, targetID).Scan(&count)
	return count, err
}

func (r *LikeRepository) IsLiked(ctx context.Context, userID uuid.UUID, targetType string, targetID uuid.UUID) (bool, error) {
	query := `SELECT 1 FROM likes WHERE user_id = $1 AND target_type = $2 AND target_id = $3`
	err := r.pool.QueryRow(ctx, query, userID, targetType, targetID).Scan(new(int))
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return false, nil
		}
		return false, err
	}
	return true, nil
}
