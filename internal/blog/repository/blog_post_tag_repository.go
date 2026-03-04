package repository

import (
	"context"
	"errors"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type BlogPostTagRepository struct {
	pool *pgxpool.Pool
}

func NewBlogPostTagRepository(pool *pgxpool.Pool) *BlogPostTagRepository {
	return &BlogPostTagRepository{pool: pool}
}

func (r *BlogPostTagRepository) Add(ctx context.Context, postID, tagID uuid.UUID) error {
	query := `INSERT INTO blog_post_tags (post_id, tag_id) VALUES ($1, $2)`
	_, err := r.pool.Exec(ctx, query, postID, tagID)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil
		}
		return err
	}
	return nil
}

func (r *BlogPostTagRepository) Remove(ctx context.Context, postID, tagID uuid.UUID) error {
	query := `DELETE FROM blog_post_tags WHERE post_id = $1 AND tag_id = $2`
	_, err := r.pool.Exec(ctx, query, postID, tagID)
	return err
}

func (r *BlogPostTagRepository) TagIDsByPostID(ctx context.Context, postID uuid.UUID) ([]uuid.UUID, error) {
	query := `SELECT tag_id FROM blog_post_tags WHERE post_id = $1 ORDER BY tag_id ASC`
	rows, err := r.pool.Query(ctx, query, postID)
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

func (r *BlogPostTagRepository) PostIDsByTagID(ctx context.Context, tagID uuid.UUID, limit, offset int) ([]uuid.UUID, error) {
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
		SELECT post_id FROM blog_post_tags
		WHERE tag_id = $1
		ORDER BY post_id ASC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, tagID, limit, offset)
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
