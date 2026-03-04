package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type TrainerClientRepository interface {
	Create(ctx context.Context, trainerID, clientID uuid.UUID, status string) (*TrainerClient, error)
	GetByTrainerAndClient(ctx context.Context, trainerID, clientID uuid.UUID) (*TrainerClient, error)
	UpdateStatus(ctx context.Context, trainerID, clientID uuid.UUID, status string) (*TrainerClient, error)
	ListClientsByTrainer(ctx context.Context, trainerID uuid.UUID, status string, limit, offset int) ([]*TrainerClient, error)
	ListTrainersByClient(ctx context.Context, clientID uuid.UUID, status string, limit, offset int) ([]*TrainerClient, error)
}

type TrainingProgramRepository interface {
	Create(ctx context.Context, trainerID, clientID uuid.UUID, name string, assignedAt *time.Time) (*TrainingProgram, error)
	GetByID(ctx context.Context, id uuid.UUID) (*TrainingProgram, error)
	Update(ctx context.Context, id uuid.UUID, name string, assignedAt *time.Time) (*TrainingProgram, error)
	Delete(ctx context.Context, id uuid.UUID) error
	ListByTrainer(ctx context.Context, trainerID uuid.UUID, clientID *uuid.UUID, limit, offset int) ([]*TrainingProgram, error)
	ListByClient(ctx context.Context, clientID uuid.UUID, limit, offset int) ([]*TrainingProgram, error)
}

type TrainerCommentRepository interface {
	Create(ctx context.Context, trainerID, clientID uuid.UUID, content string) (*TrainerComment, error)
	ListByTrainerAndClient(ctx context.Context, trainerID, clientID uuid.UUID, limit, offset int) ([]*TrainerComment, error)
}
