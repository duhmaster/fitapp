package repository

import (
	"context"
	"errors"

	blogdomain "github.com/fitflow/fitflow/internal/blog/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type BlogPostRepository struct {
	pool *pgxpool.Pool
}

func NewBlogPostRepository(pool *pgxpool.Pool) *BlogPostRepository {
	return &BlogPostRepository{pool: pool}
}

func (r *BlogPostRepository) Create(ctx context.Context, userID uuid.UUID, title string, content *string) (*blogdomain.BlogPost, error) {
	query := `
		INSERT INTO blog_posts (user_id, title, content)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, title, content, created_at, updated_at, deleted_at
	`
	var p blogdomain.BlogPost
	err := r.pool.QueryRow(ctx, query, userID, title, content).Scan(
		&p.ID, &p.UserID, &p.Title, &p.Content, &p.CreatedAt, &p.UpdatedAt, &p.DeletedAt,
	)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *BlogPostRepository) GetByID(ctx context.Context, id uuid.UUID) (*blogdomain.BlogPost, error) {
	query := `
		SELECT id, user_id, title, content, created_at, updated_at, deleted_at
		FROM blog_posts WHERE id = $1
	`
	var p blogdomain.BlogPost
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&p.ID, &p.UserID, &p.Title, &p.Content, &p.CreatedAt, &p.UpdatedAt, &p.DeletedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, blogdomain.ErrBlogPostNotFound
		}
		return nil, err
	}
	return &p, nil
}

func (r *BlogPostRepository) Update(ctx context.Context, id uuid.UUID, title string, content *string) (*blogdomain.BlogPost, error) {
	query := `
		UPDATE blog_posts
		SET title = $2, content = $3, updated_at = NOW()
		WHERE id = $1
		RETURNING id, user_id, title, content, created_at, updated_at, deleted_at
	`
	var p blogdomain.BlogPost
	err := r.pool.QueryRow(ctx, query, id, title, content).Scan(
		&p.ID, &p.UserID, &p.Title, &p.Content, &p.CreatedAt, &p.UpdatedAt, &p.DeletedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, blogdomain.ErrBlogPostNotFound
		}
		return nil, err
	}
	return &p, nil
}

func (r *BlogPostRepository) SoftDelete(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE blog_posts SET deleted_at = NOW() WHERE id = $1`
	ct, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return blogdomain.ErrBlogPostNotFound
	}
	return nil
}

func (r *BlogPostRepository) ListByUserID(ctx context.Context, userID uuid.UUID, limit, offset int) ([]*blogdomain.BlogPost, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, user_id, title, content, created_at, updated_at, deleted_at
		FROM blog_posts
		WHERE user_id = $1 AND deleted_at IS NULL
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`
	rows, err := r.pool.Query(ctx, query, userID, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*blogdomain.BlogPost
	for rows.Next() {
		var p blogdomain.BlogPost
		if err := rows.Scan(&p.ID, &p.UserID, &p.Title, &p.Content, &p.CreatedAt, &p.UpdatedAt, &p.DeletedAt); err != nil {
			return nil, err
		}
		list = append(list, &p)
	}
	return list, rows.Err()
}

func (r *BlogPostRepository) List(ctx context.Context, tagID *uuid.UUID, limit, offset int) ([]*blogdomain.BlogPost, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	if tagID != nil {
		query := `
			SELECT p.id, p.user_id, p.title, p.content, p.created_at, p.updated_at, p.deleted_at
			FROM blog_posts p
			JOIN blog_post_tags pt ON p.id = pt.post_id
			WHERE pt.tag_id = $1 AND p.deleted_at IS NULL
			ORDER BY p.created_at DESC
			LIMIT $2 OFFSET $3
		`
		rows, err := r.pool.Query(ctx, query, tagID, limit, offset)
		if err != nil {
			return nil, err
		}
		defer rows.Close()

		var list []*blogdomain.BlogPost
		for rows.Next() {
			var p blogdomain.BlogPost
			if err := rows.Scan(&p.ID, &p.UserID, &p.Title, &p.Content, &p.CreatedAt, &p.UpdatedAt, &p.DeletedAt); err != nil {
				return nil, err
			}
			list = append(list, &p)
		}
		return list, rows.Err()
	}

	query := `
		SELECT id, user_id, title, content, created_at, updated_at, deleted_at
		FROM blog_posts
		WHERE deleted_at IS NULL
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.pool.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*blogdomain.BlogPost
	for rows.Next() {
		var p blogdomain.BlogPost
		if err := rows.Scan(&p.ID, &p.UserID, &p.Title, &p.Content, &p.CreatedAt, &p.UpdatedAt, &p.DeletedAt); err != nil {
			return nil, err
		}
		list = append(list, &p)
	}
	return list, rows.Err()
}
