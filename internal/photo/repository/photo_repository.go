package repository

import (
	"context"
	"errors"

	photodomain "github.com/fitflow/fitflow/internal/photo/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PhotoRepository struct {
	pool *pgxpool.Pool
}

func NewPhotoRepository(pool *pgxpool.Pool) *PhotoRepository {
	return &PhotoRepository{pool: pool}
}

func (r *PhotoRepository) Create(ctx context.Context, bucketID uuid.UUID, objectKey, url string, uploadedBy *uuid.UUID) (*photodomain.Photo, error) {
	query := `
		INSERT INTO photos (bucket_id, object_key, url, uploaded_by_user_id)
		VALUES ($1, $2, $3, $4)
		RETURNING id, bucket_id, object_key, url, uploaded_by_user_id, created_at
	`
	var p photodomain.Photo
	err := r.pool.QueryRow(ctx, query, bucketID, objectKey, url, uploadedBy).Scan(
		&p.ID, &p.BucketID, &p.ObjectKey, &p.URL, &p.UploadedByUserID, &p.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &p, nil
}

func (r *PhotoRepository) GetByID(ctx context.Context, id uuid.UUID) (*photodomain.Photo, error) {
	query := `SELECT id, bucket_id, object_key, url, uploaded_by_user_id, created_at FROM photos WHERE id = $1`
	var p photodomain.Photo
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&p.ID, &p.BucketID, &p.ObjectKey, &p.URL, &p.UploadedByUserID, &p.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, photodomain.ErrPhotoNotFound
		}
		return nil, err
	}
	return &p, nil
}

func (r *PhotoRepository) List(ctx context.Context, limit, offset int) ([]*photodomain.Photo, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 200 {
		limit = 200
	}
	if offset < 0 {
		offset = 0
	}
	query := `
		SELECT id, bucket_id, object_key, url, uploaded_by_user_id, created_at
		FROM photos
		ORDER BY created_at DESC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.pool.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*photodomain.Photo
	for rows.Next() {
		var p photodomain.Photo
		if err := rows.Scan(&p.ID, &p.BucketID, &p.ObjectKey, &p.URL, &p.UploadedByUserID, &p.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, &p)
	}
	return out, rows.Err()
}

func (r *PhotoRepository) Delete(ctx context.Context, id uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `DELETE FROM photos WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return photodomain.ErrPhotoNotFound
	}
	return nil
}
