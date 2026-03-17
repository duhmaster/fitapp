package usecase

import (
	"context"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	"github.com/google/uuid"
)

// GymLinkerForClient описывает минимальное API для привязки залов к пользователю.
type GymLinkerForClient interface {
	Add(ctx context.Context, userID, gymID uuid.UUID) error
	HasGym(ctx context.Context, userID, gymID uuid.UUID) (bool, error)
}

// AddGymToClientIfMissing привязывает зал к подопечному, если его ещё нет.
func (uc *TrainerUseCase) AddGymToClientIfMissing(
	ctx context.Context,
	trainer *authdomain.User,
	clientID uuid.UUID,
	gymID uuid.UUID,
) error {
	// Проверяем, что это наш подопечный.
	ok, err := uc.IsClientOfTrainer(ctx, trainer.ID, clientID)
	if err != nil {
		return err
	}
	if !ok {
		return gymdomain.ErrGymNotFound
	}
	has, err := uc.userGyms.HasGym(ctx, clientID, gymID)
	if err != nil {
		return err
	}
	if has {
		return nil
	}
	return uc.userGyms.Add(ctx, clientID, gymID)
}

