package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type NotificationRepository interface {
	Create(ctx context.Context, userID uuid.UUID, notifType string, payload []byte) (*Notification, error)
	GetByID(ctx context.Context, id uuid.UUID) (*Notification, error)
	MarkRead(ctx context.Context, id uuid.UUID, at time.Time) (*Notification, error)
	MarkAllRead(ctx context.Context, userID uuid.UUID, at time.Time) (int64, error)
	ListByUserID(ctx context.Context, userID uuid.UUID, unreadOnly bool, limit, offset int) ([]*Notification, error)
}
