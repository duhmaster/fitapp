package usecase

import (
	"context"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	recdomain "github.com/fitflow/fitflow/internal/recommendation/domain"
)

type UseCase struct {
	repo recdomain.Repository
}

func New(repo recdomain.Repository) *UseCase {
	return &UseCase{repo: repo}
}

func (uc *UseCase) ListMine(ctx context.Context, user *authdomain.User, limit int) ([]*recdomain.Recommendation, error) {
	return uc.repo.ListByUserID(ctx, user.ID, limit)
}

func (uc *UseCase) ProcessOutbox(ctx context.Context, limit int) (int, error) {
	return uc.repo.ProcessOutbox(ctx, limit)
}
