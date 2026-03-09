package repository

import (
	"context"
	"errors"

	blogdomain "github.com/fitflow/fitflow/internal/blog/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
)

type TagRepository struct {
	pool *pgxpool.Pool
}

func NewTagRepository(pool *pgxpool.Pool) *TagRepository {
	return &TagRepository{pool: pool}
}

func (r *TagRepository) Create(ctx context.Context, name string) (*blogdomain.Tag, error) {
	query := `
		INSERT INTO tags (name)
		VALUES ($1)
		RETURNING id, name
	`
	var t blogdomain.Tag
	err := r.pool.QueryRow(ctx, query, name).Scan(&t.ID, &t.Name)
	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) && pgErr.Code == "23505" {
			return nil, blogdomain.ErrTagExists
		}
		return nil, err
	}
	return &t, nil
}

func (r *TagRepository) GetByID(ctx context.Context, id uuid.UUID) (*blogdomain.Tag, error) {
	query := `SELECT id, name FROM tags WHERE id = $1`
	var t blogdomain.Tag
	err := r.pool.QueryRow(ctx, query, id).Scan(&t.ID, &t.Name)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, blogdomain.ErrTagNotFound
		}
		return nil, err
	}
	return &t, nil
}

func (r *TagRepository) GetByName(ctx context.Context, name string) (*blogdomain.Tag, error) {
	query := `SELECT id, name FROM tags WHERE name = $1`
	var t blogdomain.Tag
	err := r.pool.QueryRow(ctx, query, name).Scan(&t.ID, &t.Name)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, blogdomain.ErrTagNotFound
		}
		return nil, err
	}
	return &t, nil
}

func (r *TagRepository) List(ctx context.Context, limit, offset int) ([]*blogdomain.Tag, error) {
	if limit <= 0 {
		limit = 100
	}
	if limit > 200 {
		limit = 200
	}
	if offset < 0 {
		offset = 0
	}

	query := `
		SELECT id, name FROM tags
		ORDER BY name ASC
		LIMIT $1 OFFSET $2
	`
	rows, err := r.pool.Query(ctx, query, limit, offset)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*blogdomain.Tag
	for rows.Next() {
		var t blogdomain.Tag
		if err := rows.Scan(&t.ID, &t.Name); err != nil {
			return nil, err
		}
		list = append(list, &t)
	}
	return list, rows.Err()
}

func (r *TagRepository) Delete(ctx context.Context, id uuid.UUID) error {
	query := `DELETE FROM tags WHERE id = $1`
	ct, err := r.pool.Exec(ctx, query, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return blogdomain.ErrTagNotFound
	}
	return nil
}
