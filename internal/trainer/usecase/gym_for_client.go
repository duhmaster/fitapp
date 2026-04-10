package usecase

import (
	"context"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	"github.com/google/uuid"
)

// AddGymToClientIfMissing привязывает зал к подопечному (личные залы — purpose personal), если его ещё нет.
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
	has, err := uc.userGyms.HasGymWithPurpose(ctx, clientID, gymID, gymdomain.UserGymPurposePersonal)
	if err != nil {
		return err
	}
	if has {
		return nil
	}
	return uc.userGyms.Add(ctx, clientID, gymID, gymdomain.UserGymPurposePersonal)
}

