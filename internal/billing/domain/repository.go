package domain

import (
	"context"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/google/uuid"
)

type Repository interface {
	ListActivePlans(ctx context.Context) ([]*Plan, error)
	GetPlanByCode(ctx context.Context, code string) (*Plan, error)
	GetLatestEntitlingSubscription(ctx context.Context, userID uuid.UUID, now time.Time) (*Subscription, error)
	GetUserRecord(ctx context.Context, userID uuid.UUID) (*authdomain.UserRecord, error)
	CountActiveTrainerClients(ctx context.Context, trainerID uuid.UUID) (int, error)
	CreatePayment(ctx context.Context, p *Payment) (*Payment, error)
	GetPaymentByID(ctx context.Context, paymentID uuid.UUID) (*Payment, error)
	MarkPaymentStatus(ctx context.Context, paymentID uuid.UUID, status PaymentStatus) error
	ActivateSubscriptionForPayment(ctx context.Context, paymentID uuid.UUID) error
	GetPaymentByProviderPaymentID(ctx context.Context, provider, providerPaymentID string) (*Payment, error)
	InsertProviderEvent(ctx context.Context, ev *ProviderEvent) (bool, error)
	MarkProviderEventProcessed(ctx context.Context, provider, providerEventID string) error
}
