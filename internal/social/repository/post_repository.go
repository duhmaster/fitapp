package repository

import (
	"context"
	"errors"

	socialdomain "github.com/fitflow/fitflow/internal/social/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PostRepository struct {
	pool *pgxpool.Pool
}

func NewPostRepository(pool *pgxpool.Pool) *PostRepository {
	return &PostRepository{pool: pool}
}

func (r *PostRepository) Create(ctx context.Context, userID uuid.UUID, content *string) (*socialdomain.Post, error) {
	query := `
		INSERT INTO posts (user_id, content)
		VALUES ($1, $2)
		RETURNING id, user_id, content, created_at
	`
	var p socialdomain.Post
	err := r.pool.QueryRow(ctx, query, userID, content).Scan(&p.ID, &p.UserID, &p.Content, &p.CreatedAt)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *PostRepository) GetByID(ctx context.Context, id uuid.UUID) (*socialdomain.Post, error) {
	query := `
		SELECT id, user_id, content, created_at
		FROM posts WHERE id = $1
	`
	var p socialdomain.Post
	err := r.pool.QueryRow(ctx, query, id).Scan(&p.ID, &p.UserID, &p.Content, &p.CreatedAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, socialdomain.ErrPostNotFound
		}
		return nil, err
	}
	return &p, nil
}

func (r *PostRepository) ListByUserIDs(ctx context.Context, userIDs []uuid.UUID, limit, offset int) ([]*socialdomain.Post, error) {
	if len(userIDs) == 0 {
		return nil, nil
	}
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
		SELECT id, user_id, content, created_at
		FROM posts
		WHERE user_id = ANY($1)
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, userIDs, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*socialdomain.Post
	for rows.Next() {
		var p socialdomain.Post
		if err := rows.Scan(&p.ID, &p.UserID, &p.Content, &p.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &p)
	}
	return list, rows.Err()
}

func (r *PostRepository) ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*socialdomain.Post, error) {
	return r.ListByUserIDs(ctx, []uuid.UUID{userID}, limit, offset)
}
