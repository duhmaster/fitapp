package repository

import (
	"context"

	socialdomain "github.com/fitflow/fitflow/internal/social/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type CommentRepository struct {
	pool *pgxpool.Pool
}

func NewCommentRepository(pool *pgxpool.Pool) *CommentRepository {
	return &CommentRepository{pool: pool}
}

func (r *CommentRepository) Create(ctx context.Context, userID uuid.UUID, targetType string, targetID uuid.UUID, content string) (*socialdomain.Comment, error) {
	query := `
		INSERT INTO comments (user_id, target_type, target_id, content)
		VALUES ($1, $2, $3, $4)
		RETURNING id, user_id, target_type, target_id, content, created_at
	`
	var c socialdomain.Comment
	err := r.pool.QueryRow(ctx, query, userID, targetType, targetID, content).Scan(
		&c.ID, &c.UserID, &c.TargetType, &c.TargetID, &c.Content, &c.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &c, nil
}

func (r *CommentRepository) ListByTarget(ctx context.Context, targetType string, targetID uuid.UUID, limit, offset int) ([]*socialdomain.Comment, error) {
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
		SELECT id, user_id, target_type, target_id, content, created_at
		FROM comments
		WHERE target_type = $1 AND target_id = $2
		ORDER BY created_at ASC
		LIMIT $3 OFFSET $4
	`
	rows, err := r.pool.Query(ctx, query, targetType, targetID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*socialdomain.Comment
	for rows.Next() {
		var c socialdomain.Comment
		if err := rows.Scan(&c.ID, &c.UserID, &c.TargetType, &c.TargetID, &c.Content, &c.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &c)
	}
	return list, rows.Err()
}
