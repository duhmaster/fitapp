package repository

import (
	"context"
	"errors"

	blogdomain "github.com/fitflow/fitflow/internal/blog/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type BlogPostPhotoRepository struct {
	pool *pgxpool.Pool
}

func NewBlogPostPhotoRepository(pool *pgxpool.Pool) *BlogPostPhotoRepository {
	return &BlogPostPhotoRepository{pool: pool}
}

func (r *BlogPostPhotoRepository) Create(ctx context.Context, postID uuid.UUID, url string, sortOrder int) (*blogdomain.BlogPostPhoto, error) {
	query := `
		INSERT INTO blog_post_photos (post_id, url, sort_order)
		VALUES ($1, $2, $3)
		RETURNING id, post_id, url, sort_order
	`
	var ph blogdomain.BlogPostPhoto
	err := r.pool.QueryRow(ctx, query, postID, url, sortOrder).Scan(
		&ph.ID, &ph.PostID, &ph.URL, &ph.SortOrder,
	)
	if err != nil {
		return nil, err
	}
	return &ph, nil
}

func (r *BlogPostPhotoRepository) GetByID(ctx context.Context, id uuid.UUID) (*blogdomain.BlogPostPhoto, error) {
	query := `SELECT id, post_id, url, sort_order FROM blog_post_photos WHERE id = $1`
	var ph blogdomain.BlogPostPhoto
	err := r.pool.QueryRow(ctx, query, id).Scan(&ph.ID, &ph.PostID, &ph.URL, &ph.SortOrder)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, blogdomain.ErrBlogPostPhotoNotFound
		}
		return nil, err
	}
	return &ph, nil
}

func (r *BlogPostPhotoRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM blog_post_photos WHERE id = $1`
	_, err := r.pool.Exec(ctx, query, id)
	return err
}

func (r *BlogPostPhotoRepository) ListByPostID(ctx context.Context, postID uuid.UUID) ([]*blogdomain.BlogPostPhoto, error) {
	query := `
		SELECT id, post_id, url, sort_order
		FROM blog_post_photos
		WHERE post_id = $1
		ORDER BY sort_order ASC, id ASC
	`
	rows, err := r.pool.Query(ctx, query, postID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*blogdomain.BlogPostPhoto
	for rows.Next() {
		var ph blogdomain.BlogPostPhoto
		if err := rows.Scan(&ph.ID, &ph.PostID, &ph.URL, &ph.SortOrder); err != nil {
			return nil, err
		}
		list = append(list, &ph)
	}
	return list, rows.Err()
}
