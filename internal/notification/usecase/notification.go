package usecase

import (
	"context"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	notificationdomain "github.com/fitflow/fitflow/internal/notification/domain"
	"github.com/google/uuid"
)

type NotificationUseCase struct {
	repo notificationdomain.NotificationRepository
}

func NewNotificationUseCase(repo notificationdomain.NotificationRepository) *NotificationUseCase {
	return &NotificationUseCase{repo: repo}
}

func (uc *NotificationUseCase) Create(ctx context.Context, userID uuid.UUID, notifType string, payload []byte) (*notificationdomain.Notification, error) {
	return uc.repo.Create(ctx, userID, notifType, payload)
}

func (uc *NotificationUseCase) Get(ctx context.Context, id uuid.UUID) (*notificationdomain.Notification, error) {
	return uc.repo.GetByID(ctx, id)
}

func (uc *NotificationUseCase) MarkRead(ctx context.Context, user *authdomain.User, id uuid.UUID, at time.Time) (*notificationdomain.Notification, error) {
	n, err := uc.repo.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if n.UserID != user.ID {
		return nil, notificationdomain.ErrNotificationNotFound
	}
	return uc.repo.MarkRead(ctx, id, at)
}

func (uc *NotificationUseCase) MarkAllRead(ctx context.Context, user *authdomain.User, at time.Time) (int64, error) {
	return uc.repo.MarkAllRead(ctx, user.ID, at)
}

func (uc *NotificationUseCase) List(ctx context.Context, user *authdomain.User, unreadOnly bool, limit, offset int) ([]*notificationdomain.Notification, error) {
	return uc.repo.ListByUserID(ctx, user.ID, unreadOnly, limit, offset)
}
