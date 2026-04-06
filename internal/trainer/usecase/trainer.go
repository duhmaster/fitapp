package usecase

import (
	"context"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	trainerdomain "github.com/fitflow/fitflow/internal/trainer/domain"
	"github.com/google/uuid"
)

type TrainerUseCase struct {
	clients   trainerdomain.TrainerClientRepository
	programs  trainerdomain.TrainingProgramRepository
	comments  trainerdomain.TrainerCommentRepository
	profile   trainerdomain.TrainerProfileRepository
	photos    trainerdomain.TrainerPhotoRepository
	userGyms  gymdomain.UserGymRepository
}

func NewTrainerUseCase(
	clients trainerdomain.TrainerClientRepository,
	programs trainerdomain.TrainingProgramRepository,
	comments trainerdomain.TrainerCommentRepository,
	profile trainerdomain.TrainerProfileRepository,
	photos trainerdomain.TrainerPhotoRepository,
	userGyms gymdomain.UserGymRepository,
) *TrainerUseCase {
	return &TrainerUseCase{
		clients:  clients,
		programs: programs,
		comments: comments,
		profile:  profile,
		photos:   photos,
		userGyms: userGyms,
	}
}

func (uc *TrainerUseCase) AddClient(ctx context.Context, trainer *authdomain.User, clientID uuid.UUID, status string) (*trainerdomain.TrainerClient, error) {
	return uc.clients.Create(ctx, trainer.ID, clientID, status)
}

func (uc *TrainerUseCase) SetClientStatus(ctx context.Context, trainer *authdomain.User, clientID uuid.UUID, status string) (*trainerdomain.TrainerClient, error) {
	return uc.clients.UpdateStatus(ctx, trainer.ID, clientID, status)
}

// RemoveClient removes a trainee (client) from the trainer's list.
func (uc *TrainerUseCase) RemoveClient(ctx context.Context, trainer *authdomain.User, clientID uuid.UUID) error {
	return uc.clients.Remove(ctx, trainer.ID, clientID)
}

// IsClientOfTrainer returns true if clientID is linked to trainerID (trainer can view client's data).
func (uc *TrainerUseCase) IsClientOfTrainer(ctx context.Context, trainerID, clientID uuid.UUID) (bool, error) {
	_, err := uc.clients.GetByTrainerAndClient(ctx, trainerID, clientID)
	if err != nil {
		if err == trainerdomain.ErrTrainerClientNotFound {
			return false, nil
		}
		return false, err
	}
	return true, nil
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

// GetMyTrainerProfile returns the current user's trainer profile, or ErrTrainerProfileNotFound if not a trainer.
func (uc *TrainerUseCase) GetMyTrainerProfile(ctx context.Context, user *authdomain.User) (*trainerdomain.TrainerProfile, error) {
	return uc.profile.GetByUserID(ctx, user.ID)
}

// GetTrainerProfileByUserID returns trainer profile by user ID (for public profile).
func (uc *TrainerUseCase) GetTrainerProfileByUserID(ctx context.Context, userID uuid.UUID) (*trainerdomain.TrainerProfile, error) {
	return uc.profile.GetByUserID(ctx, userID)
}

// ListTrainerPhotosByUserID returns photos for a trainer by user ID (for public profile).
func (uc *TrainerUseCase) ListTrainerPhotosByUserID(ctx context.Context, userID uuid.UUID) ([]*trainerdomain.TrainerPhoto, error) {
	return uc.photos.ListByTrainerUserID(ctx, userID)
}

// CountTrainees returns the number of clients for a trainer.
func (uc *TrainerUseCase) CountTrainees(ctx context.Context, trainerID uuid.UUID) (int, error) {
	return uc.clients.CountByTrainerID(ctx, trainerID)
}

// UpdateMyTrainerProfile creates or updates the trainer profile for the current user (makes them a trainer).
func (uc *TrainerUseCase) UpdateMyTrainerProfile(ctx context.Context, user *authdomain.User, aboutMe, contacts string) (*trainerdomain.TrainerProfile, error) {
	p := &trainerdomain.TrainerProfile{UserID: user.ID, AboutMe: aboutMe, Contacts: contacts}
	if err := uc.profile.Upsert(ctx, p); err != nil {
		return nil, err
	}
	return uc.profile.GetByUserID(ctx, user.ID)
}

func (uc *TrainerUseCase) ListMyTrainerPhotos(ctx context.Context, user *authdomain.User) ([]*trainerdomain.TrainerPhoto, error) {
	return uc.photos.ListByTrainerUserID(ctx, user.ID)
}

func (uc *TrainerUseCase) AddTrainerPhoto(ctx context.Context, user *authdomain.User, path string, position int) (*trainerdomain.TrainerPhoto, error) {
	n, err := uc.photos.CountByTrainerUserID(ctx, user.ID)
	if err != nil {
		return nil, err
	}
	if n >= trainerdomain.MaxTrainerProfilePhotos {
		return nil, trainerdomain.ErrTrainerPhotoLimitReached
	}
	return uc.photos.Create(ctx, user.ID, path, position)
}

func (uc *TrainerUseCase) DeleteTrainerPhoto(ctx context.Context, user *authdomain.User, photoID uuid.UUID) error {
	ph, err := uc.photos.GetByID(ctx, photoID)
	if err != nil {
		return err
	}
	if ph.TrainerUserID != user.ID {
		return trainerdomain.ErrTrainerPhotoNotFound
	}
	return uc.photos.Delete(ctx, photoID)
}

// SearchTrainerUserIDs returns user IDs of users who have a trainer profile and match the query.
func (uc *TrainerUseCase) SearchTrainerUserIDs(ctx context.Context, query string, limit int) ([]uuid.UUID, error) {
	return uc.profile.SearchTrainerUserIDs(ctx, query, limit)
}

// AddMyTrainer links the current user (client) to a trainer. The trainer must have a trainer profile.
func (uc *TrainerUseCase) AddMyTrainer(ctx context.Context, client *authdomain.User, trainerID uuid.UUID) (*trainerdomain.TrainerClient, error) {
	if _, err := uc.profile.GetByUserID(ctx, trainerID); err != nil {
		return nil, trainerdomain.ErrTrainerProfileNotFound
	}
	return uc.clients.Create(ctx, trainerID, client.ID, "active")
}

// RemoveMyTrainer unlinks the current user from a trainer.
func (uc *TrainerUseCase) RemoveMyTrainer(ctx context.Context, client *authdomain.User, trainerID uuid.UUID) error {
	return uc.clients.Remove(ctx, trainerID, client.ID)
}
