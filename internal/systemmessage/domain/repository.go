package domain

import (
	"context"

	"github.com/google/uuid"
)

type Repository interface {
	List(ctx context.Context, activeOnly bool, limit, offset int) ([]*SystemMessage, error)
	CountActive(ctx context.Context) (int, error)
	GetByID(ctx context.Context, id uuid.UUID) (*SystemMessage, error)
	Create(ctx context.Context, title, body string, isActive bool) (*SystemMessage, error)
	Update(ctx context.Context, id uuid.UUID, title, body string, isActive bool) (*SystemMessage, error)
	Delete(ctx context.Context, id uuid.UUID) error
}

