package repository

import (
	"context"
	"errors"

	systemmessagedomain "github.com/fitflow/fitflow/internal/systemmessage/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type Repository struct {
	pool *pgxpool.Pool
}

func New(pool *pgxpool.Pool) *Repository {
	return &Repository{pool: pool}
}

func (r *Repository) List(ctx context.Context, activeOnly bool, limit, offset int) ([]*systemmessagedomain.SystemMessage, error) {
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
		SELECT id, created_at, title, body, is_active
		FROM system_messages
		WHERE 1=1
	`
	if activeOnly {
		query += " AND is_active = TRUE"
	}
	query += " ORDER BY created_at DESC"
	query += " LIMIT $1 OFFSET $2"
	args := []interface{}{limit, offset}

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*systemmessagedomain.SystemMessage
	for rows.Next() {
		var m systemmessagedomain.SystemMessage
		if err := rows.Scan(&m.ID, &m.CreatedAt, &m.Title, &m.Body, &m.IsActive); err != nil {
			return nil, err
		}
		list = append(list, &m)
	}
	return list, rows.Err()
}

func (r *Repository) CountActive(ctx context.Context) (int, error) {
	var n int
	err := r.pool.QueryRow(ctx, `SELECT COUNT(*) FROM system_messages WHERE is_active = TRUE`).Scan(&n)
	return n, err
}

func (r *Repository) GetByID(ctx context.Context, id uuid.UUID) (*systemmessagedomain.SystemMessage, error) {
	var m systemmessagedomain.SystemMessage
	err := r.pool.QueryRow(ctx, `
		SELECT id, created_at, title, body, is_active
		FROM system_messages
		WHERE id = $1
	`, id).Scan(&m.ID, &m.CreatedAt, &m.Title, &m.Body, &m.IsActive)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, systemmessagedomain.ErrSystemMessageNotFound
		}
		return nil, err
	}
	return &m, nil
}

func (r *Repository) Create(ctx context.Context, title, body string, isActive bool) (*systemmessagedomain.SystemMessage, error) {
	var m systemmessagedomain.SystemMessage
	err := r.pool.QueryRow(ctx, `
		INSERT INTO system_messages (title, body, is_active)
		VALUES ($1, $2, $3)
		RETURNING id, created_at, title, body, is_active
	`, title, body, isActive).Scan(&m.ID, &m.CreatedAt, &m.Title, &m.Body, &m.IsActive)
	if err != nil {
		return nil, err
	}
	return &m, nil
}

func (r *Repository) Update(ctx context.Context, id uuid.UUID, title, body string, isActive bool) (*systemmessagedomain.SystemMessage, error) {
	var m systemmessagedomain.SystemMessage
	err := r.pool.QueryRow(ctx, `
		UPDATE system_messages
		SET title = $2, body = $3, is_active = $4
		WHERE id = $1
		RETURNING id, created_at, title, body, is_active
	`, id, title, body, isActive).Scan(&m.ID, &m.CreatedAt, &m.Title, &m.Body, &m.IsActive)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, systemmessagedomain.ErrSystemMessageNotFound
		}
		return nil, err
	}
	return &m, nil
}

func (r *Repository) Delete(ctx context.Context, id uuid.UUID) error {
	ct, err := r.pool.Exec(ctx, `DELETE FROM system_messages WHERE id = $1`, id)
	if err != nil {
		return err
	}
	if ct.RowsAffected() == 0 {
		return systemmessagedomain.ErrSystemMessageNotFound
	}
	return nil
}
