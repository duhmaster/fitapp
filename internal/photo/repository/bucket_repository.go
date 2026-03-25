package repository

import (
	"context"
	"errors"

	photodomain "github.com/fitflow/fitflow/internal/photo/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type BucketRepository struct {
	pool *pgxpool.Pool
}

func NewBucketRepository(pool *pgxpool.Pool) *BucketRepository {
	return &BucketRepository{pool: pool}
}

func (r *BucketRepository) GetByID(ctx context.Context, id uuid.UUID) (*photodomain.Bucket, error) {
	query := `SELECT id, name, endpoint, region, public_url, created_at FROM buckets WHERE id = $1`
	var b photodomain.Bucket
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&b.ID, &b.Name, &b.Endpoint, &b.Region, &b.PublicURL, &b.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, photodomain.ErrBucketNotFound
		}
		return nil, err
	}
	return &b, nil
}

func (r *BucketRepository) GetByName(ctx context.Context, name string) (*photodomain.Bucket, error) {
	query := `SELECT id, name, endpoint, region, public_url, created_at FROM buckets WHERE name = $1`
	var b photodomain.Bucket
	err := r.pool.QueryRow(ctx, query, name).Scan(
		&b.ID, &b.Name, &b.Endpoint, &b.Region, &b.PublicURL, &b.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, photodomain.ErrBucketNotFound
		}
		return nil, err
	}
	return &b, nil
}

func (r *BucketRepository) List(ctx context.Context) ([]*photodomain.Bucket, error) {
	query := `SELECT id, name, endpoint, region, public_url, created_at FROM buckets ORDER BY name`
	rows, err := r.pool.Query(ctx, query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()
	var out []*photodomain.Bucket
	for rows.Next() {
		var b photodomain.Bucket
		if err := rows.Scan(&b.ID, &b.Name, &b.Endpoint, &b.Region, &b.PublicURL, &b.CreatedAt); err != nil {
			return nil, err
		}
		out = append(out, &b)
	}
	return out, rows.Err()
}

func (r *BucketRepository) Create(ctx context.Context, name, endpoint, region, publicURL string) (*photodomain.Bucket, error) {
	query := `
		INSERT INTO buckets (name, endpoint, region, public_url)
		VALUES ($1, $2, $3, $4)
		RETURNING id, name, endpoint, region, public_url, created_at
	`
	var b photodomain.Bucket
	err := r.pool.QueryRow(ctx, query, name, endpoint, region, publicURL).Scan(
		&b.ID, &b.Name, &b.Endpoint, &b.Region, &b.PublicURL, &b.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &b, nil
}

func (r *BucketRepository) Update(ctx context.Context, id uuid.UUID, name, endpoint, region, publicURL string) (*photodomain.Bucket, error) {
	query := `
		UPDATE buckets SET name = $2, endpoint = $3, region = $4, public_url = $5
		WHERE id = $1
		RETURNING id, name, endpoint, region, public_url, created_at
	`
	var b photodomain.Bucket
	err := r.pool.QueryRow(ctx, query, id, name, endpoint, region, publicURL).Scan(
		&b.ID, &b.Name, &b.Endpoint, &b.Region, &b.PublicURL, &b.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, photodomain.ErrBucketNotFound
		}
		return nil, err
	}
	return &b, nil
}

func (r *BucketRepository) Delete(ctx context.Context, id uuid.UUID) error {
	res, err := r.pool.Exec(ctx, `DELETE FROM buckets WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return photodomain.ErrBucketNotFound
	}
	return nil
}
