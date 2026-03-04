package repository

import (
	"context"
	"errors"
	"time"

	notificationdomain "github.com/fitflow/fitflow/internal/notification/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type NotificationRepository struct {
	pool *pgxpool.Pool
}

func NewNotificationRepository(pool *pgxpool.Pool) *NotificationRepository {
	return &NotificationRepository{pool: pool}
}

func (r *NotificationRepository) Create(ctx context.Context, userID uuid.UUID, notifType string, payload []byte) (*notificationdomain.Notification, error) {
	query := `
		INSERT INTO notifications (user_id, type, payload)
		VALUES ($1, $2, $3)
		RETURNING id, user_id, type, payload, read_at, created_at
	`
	var n notificationdomain.Notification
	err := r.pool.QueryRow(ctx, query, userID, notifType, payload).Scan(
		&n.ID, &n.UserID, &n.Type, &n.Payload, &n.ReadAt, &n.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return &n, nil
}

func (r *NotificationRepository) GetByID(ctx context.Context, id uuid.UUID) (*notificationdomain.Notification, error) {
	query := `
		SELECT id, user_id, type, payload, read_at, created_at
		FROM notifications WHERE id = $1
	`
	var n notificationdomain.Notification
	err := r.pool.QueryRow(ctx, query, id).Scan(
		&n.ID, &n.UserID, &n.Type, &n.Payload, &n.ReadAt, &n.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, notificationdomain.ErrNotificationNotFound
		}
		return nil, err
	}
	return &n, nil
}

func (r *NotificationRepository) MarkRead(ctx context.Context, id uuid.UUID, at time.Time) (*notificationdomain.Notification, error) {
	query := `
		UPDATE notifications SET read_at = $2 WHERE id = $1
		RETURNING id, user_id, type, payload, read_at, created_at
	`
	var n notificationdomain.Notification
	err := r.pool.QueryRow(ctx, query, id, at).Scan(
		&n.ID, &n.UserID, &n.Type, &n.Payload, &n.ReadAt, &n.CreatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, notificationdomain.ErrNotificationNotFound
		}
		return nil, err
	}
	return &n, nil
}

func (r *NotificationRepository) MarkAllRead(ctx context.Context, userID uuid.UUID, at time.Time) (int64, error) {
	query := `UPDATE notifications SET read_at = $2 WHERE user_id = $1 AND read_at IS NULL`
	ct, err := r.pool.Exec(ctx, query, userID, at)
	if err != nil {
		return 0, err
	}
	return ct.RowsAffected(), nil
}

func (r *NotificationRepository) ListByUserID(ctx context.Context, userID uuid.UUID, unreadOnly bool, limit, offset int) ([]*notificationdomain.Notification, error) {
	if limit <= 0 {
		limit = 50
	}
	if limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	var query string
	var args []interface{}
	if unreadOnly {
		query = `
			SELECT id, user_id, type, payload, read_at, created_at
			FROM notifications
			WHERE user_id = $1 AND read_at IS NULL
			ORDER BY created_at DESC
			LIMIT $2 OFFSET $3
		`
		args = []interface{}{userID, limit, offset}
	} else {
		query = `
			SELECT id, user_id, type, payload, read_at, created_at
			FROM notifications
			WHERE user_id = $1
			ORDER BY created_at DESC
			LIMIT $2 OFFSET $3
		`
		args = []interface{}{userID, limit, offset}
	}

	rows, err := r.pool.Query(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var list []*notificationdomain.Notification
	for rows.Next() {
		var n notificationdomain.Notification
		if err := rows.Scan(&n.ID, &n.UserID, &n.Type, &n.Payload, &n.ReadAt, &n.CreatedAt); err != nil {
			return nil, err
		}
		list = append(list, &n)
	}
	return list, rows.Err()
}
