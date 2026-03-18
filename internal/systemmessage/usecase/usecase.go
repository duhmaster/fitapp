package usecase

import (
	"context"

	systemmessagedomain "github.com/fitflow/fitflow/internal/systemmessage/domain"
	"github.com/google/uuid"
)

type UseCase struct {
	repo systemmessagedomain.Repository
}

func New(repo systemmessagedomain.Repository) *UseCase {
	return &UseCase{repo: repo}
}

func (uc *UseCase) List(ctx context.Context, activeOnly bool, limit, offset int) ([]*systemmessagedomain.SystemMessage, error) {
	return uc.repo.List(ctx, activeOnly, limit, offset)
}

func (uc *UseCase) CountActive(ctx context.Context) (int, error) {
	return uc.repo.CountActive(ctx)
}

func (uc *UseCase) Get(ctx context.Context, id uuid.UUID) (*systemmessagedomain.SystemMessage, error) {
	return uc.repo.GetByID(ctx, id)
}

func (uc *UseCase) Create(ctx context.Context, title, body string, isActive bool) (*systemmessagedomain.SystemMessage, error) {
	return uc.repo.Create(ctx, title, body, isActive)
}

func (uc *UseCase) Update(ctx context.Context, id uuid.UUID, title, body string, isActive bool) (*systemmessagedomain.SystemMessage, error) {
	return uc.repo.Update(ctx, id, title, body, isActive)
}

func (uc *UseCase) Delete(ctx context.Context, id uuid.UUID) error {
	return uc.repo.Delete(ctx, id)
}

