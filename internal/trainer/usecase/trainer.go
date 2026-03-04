package usecase

import (
	"context"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	trainerdomain "github.com/fitflow/fitflow/internal/trainer/domain"
	"github.com/google/uuid"
)

type TrainerUseCase struct {
	clients   trainerdomain.TrainerClientRepository
	programs  trainerdomain.TrainingProgramRepository
	comments  trainerdomain.TrainerCommentRepository
}

func NewTrainerUseCase(
	clients trainerdomain.TrainerClientRepository,
	programs trainerdomain.TrainingProgramRepository,
	comments trainerdomain.TrainerCommentRepository,
) *TrainerUseCase {
	return &TrainerUseCase{
		clients:  clients,
		programs: programs,
		comments: comments,
	}
}

func (uc *TrainerUseCase) AddClient(ctx context.Context, trainer *authdomain.User, clientID uuid.UUID, status string) (*trainerdomain.TrainerClient, error) {
	return uc.clients.Create(ctx, trainer.ID, clientID, status)
}

func (uc *TrainerUseCase) SetClientStatus(ctx context.Context, trainer *authdomain.User, clientID uuid.UUID, status string) (*trainerdomain.TrainerClient, error) {
	return uc.clients.UpdateStatus(ctx, trainer.ID, clientID, status)
}

func (uc *TrainerUseCase) ListMyClients(ctx context.Context, trainer *authdomain.User, status string, limit, offset int) ([]*trainerdomain.TrainerClient, error) {
	return uc.clients.ListClientsByTrainer(ctx, trainer.ID, status, limit, offset)
}

func (uc *TrainerUseCase) ListMyTrainers(ctx context.Context, client *authdomain.User, status string, limit, offset int) ([]*trainerdomain.TrainerClient, error) {
	return uc.clients.ListTrainersByClient(ctx, client.ID, status, limit, offset)
}

func (uc *TrainerUseCase) CreateProgram(ctx context.Context, trainer *authdomain.User, clientID uuid.UUID, name string, assignedAt *time.Time) (*trainerdomain.TrainingProgram, error) {
	return uc.programs.Create(ctx, trainer.ID, clientID, name, assignedAt)
}

func (uc *TrainerUseCase) GetProgram(ctx context.Context, id uuid.UUID) (*trainerdomain.TrainingProgram, error) {
	return uc.programs.GetByID(ctx, id)
}

func (uc *TrainerUseCase) UpdateProgram(ctx context.Context, trainer *authdomain.User, id uuid.UUID, name string, assignedAt *time.Time) (*trainerdomain.TrainingProgram, error) {
	tp, err := uc.programs.GetByID(ctx, id)
	if err != nil {
		return nil, err
	}
	if tp.TrainerID != trainer.ID {
		return nil, trainerdomain.ErrTrainingProgramNotFound
	}
	return uc.programs.Update(ctx, id, name, assignedAt)
}

func (uc *TrainerUseCase) DeleteProgram(ctx context.Context, trainer *authdomain.User, id uuid.UUID) error {
	tp, err := uc.programs.GetByID(ctx, id)
	if err != nil {
		return err
	}
	if tp.TrainerID != trainer.ID {
		return trainerdomain.ErrTrainingProgramNotFound
	}
	return uc.programs.Delete(ctx, id)
}

func (uc *TrainerUseCase) ListProgramsAsTrainer(ctx context.Context, trainer *authdomain.User, clientID *uuid.UUID, limit, offset int) ([]*trainerdomain.TrainingProgram, error) {
	return uc.programs.ListByTrainer(ctx, trainer.ID, clientID, limit, offset)
}

func (uc *TrainerUseCase) ListProgramsAsClient(ctx context.Context, client *authdomain.User, limit, offset int) ([]*trainerdomain.TrainingProgram, error) {
	return uc.programs.ListByClient(ctx, client.ID, limit, offset)
}

func (uc *TrainerUseCase) AddComment(ctx context.Context, trainer *authdomain.User, clientID uuid.UUID, content string) (*trainerdomain.TrainerComment, error) {
	return uc.comments.Create(ctx, trainer.ID, clientID, content)
}

func (uc *TrainerUseCase) ListComments(ctx context.Context, trainerID, clientID uuid.UUID, limit, offset int) ([]*trainerdomain.TrainerComment, error) {
	return uc.comments.ListByTrainerAndClient(ctx, trainerID, clientID, limit, offset)
}
