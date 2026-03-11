package repository

import (
	"context"
	"errors"

	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type GymRepository struct {
	pool *pgxpool.Pool
}

func NewGymRepository(pool *pgxpool.Pool) *GymRepository {
	return &GymRepository{pool: pool}
}

func (r *GymRepository) Create(ctx context.Context, name, city, address, contactPhone, contactURL string, latitude, longitude *float64) (*gymdomain.Gym, error) {
	query := `
		INSERT INTO gyms (name, city, latitude, longitude, address, contact_phone, contact_url)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, name, city, latitude, longitude, address, contact_phone, contact_url, created_at, updated_at
	`
	var g gymdomain.Gym
	err := r.pool.QueryRow(ctx, query, name, city, latitude, longitude, address, contactPhone, contactURL).Scan(
		&g.ID, &g.Name, &g.City, &g.Latitude, &g.Longitude, &g.Address, &g.ContactPhone, &g.ContactURL, &g.CreatedAt, &g.UpdatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &g, nil
}

func (r *GymRepository) Update(ctx context.Context, id uuid.UUID, name, city, address, contactPhone, contactURL string, latitude, longitude *float64) (*gymdomain.Gym, error) {
	query := `
		UPDATE gyms
		SET name = $2, city = $3, latitude = $4, longitude = $5, address = $6, contact_phone = $7, contact_url = $8, updated_at = NOW()
		WHERE id = $1 AND deleted_at IS NULL
		RETURNING id, name, city, latitude, longitude, address, contact_phone, contact_url, created_at, updated_at
	`
	var g gymdomain.Gym
	err := r.pool.QueryRow(ctx, query, id, name, city, latitude, longitude, address, contactPhone, contactURL).Scan(
		&g.ID, &g.Name, &g.City, &g.Latitude, &g.Longitude, &g.Address, &g.ContactPhone, &g.ContactURL, &g.CreatedAt, &g.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, gymdomain.ErrGymNotFound
		}
		return nil, err
	}
	return &g, nil
}

func (r *GymRepository) SoftDelete(ctx context.Context, id uuid.UUID) error {
	query := `UPDATE gyms SET deleted_at = NOW() WHERE id = $1 AND deleted_at IS NULL`
	ct, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return gymdomain.ErrGymNotFound
	}
	return nil
}

func (r *GymRepository) GetByID(ctx context.Context, id uuid.UUID) (*gymdomain.Gym, error) {
	query := `
		SELECT id, name, city, latitude, longitude, address, contact_phone, contact_url, created_at, updated_at
		FROM gyms
		WHERE id = $1 AND deleted_at IS NULL
	`
	var g gymdomain.Gym
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&g.ID, &g.Name, &g.City, &g.Latitude, &g.Longitude, &g.Address, &g.ContactPhone, &g.ContactURL, &g.CreatedAt, &g.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, gymdomain.ErrGymNotFound
		}
		return nil, err
	}
	return &g, nil
}

func (r *GymRepository) Search(ctx context.Context, q, city string, latitude, longitude *float64, limit, offset int) ([]*gymdomain.Gym, error) {
	if limit <= 0 {
		limit = 20
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	// If lat/lng provided, order by approximate distance (squared) with NULL coords last.
	// If city provided, filter by city (ILIKE).
	query := `
		SELECT id, name, city, latitude, longitude, address, contact_phone, contact_url, created_at, updated_at
		FROM gyms
		WHERE deleted_at IS NULL
		  AND ($1 = '' OR name ILIKE '%' || $1 || '%')
		  AND ($4 = '' OR city ILIKE '%' || $4 || '%')
		ORDER BY
			CASE WHEN $2::float8 IS NULL OR $3::float8 IS NULL OR latitude IS NULL OR longitude IS NULL THEN 1 ELSE 0 END,
			CASE WHEN $2::float8 IS NULL OR $3::float8 IS NULL OR latitude IS NULL OR longitude IS NULL THEN NULL
			     ELSE ((latitude - $2) * (latitude - $2) + (longitude - $3) * (longitude - $3)) END ASC NULLS LAST,
			name ASC
		LIMIT $5 OFFSET $6
	`
	rows, err := r.pool.Query(ctx, query, q, latitude, longitude, city, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var gyms []*gymdomain.Gym
	for rows.Next() {
		var g gymdomain.Gym
		if err := rows.Scan(&g.ID, &g.Name, &g.City, &g.Latitude, &g.Longitude, &g.Address, &g.ContactPhone, &g.ContactURL, &g.CreatedAt, &g.UpdatedAt); err != nil {
			return nil, err
		}
		gyms = append(gyms, &g)
	}
	return gyms, rows.Err()
}

// ListIDsAfter returns gym IDs ordered by ID, starting after the given UUID.
// Used by background workers for incremental scans.
func (r *GymRepository) ListIDsAfter(ctx context.Context, after uuid.UUID, limit int) ([]uuid.UUID, error) {
	if limit <= 0 {
		limit = 1000
	}
	if limit > 5000 {
		limit = 5000
	}

	query := `
		SELECT id
		FROM gyms
		WHERE deleted_at IS NULL
		  AND ($1::uuid = '00000000-0000-0000-0000-000000000000' OR id > $1)
		ORDER BY id ASC
		LIMIT $2
	`
	rows, err := r.pool.Query(ctx, query, after, limit)
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

