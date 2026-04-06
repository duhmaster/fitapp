package usecase

import (
	"context"
	"errors"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/grouptraining/domain"
	"github.com/google/uuid"
)

func dedupeGalleryPhotoIDs(ids []uuid.UUID) []uuid.UUID {
	seen := make(map[uuid.UUID]struct{})
	out := make([]uuid.UUID, 0, len(ids))
	for _, id := range ids {
		if _, ok := seen[id]; ok {
			continue
		}
		seen[id] = struct{}{}
		out = append(out, id)
	}
	return out
}

type GroupTrainingUseCase struct {
	types        domain.GroupTrainingTypeRepository
	templates    domain.GroupTrainingTemplateRepository
	trainings    domain.GroupTrainingRepository
	registrations domain.GroupTrainingRegistrationRepository

	users authdomain.UserRepository
}

func NewGroupTrainingUseCase(
	types domain.GroupTrainingTypeRepository,
	templates domain.GroupTrainingTemplateRepository,
	trainings domain.GroupTrainingRepository,
	registrations domain.GroupTrainingRegistrationRepository,
	users authdomain.UserRepository,
) *GroupTrainingUseCase {
	return &GroupTrainingUseCase{
		types:         types,
		templates:     templates,
		trainings:     trainings,
		registrations: registrations,
		users:         users,
	}
}

func (uc *GroupTrainingUseCase) ListTypes(ctx context.Context) ([]*domain.GroupTrainingType, error) {
	return uc.types.List(ctx)
}

func (uc *GroupTrainingUseCase) CreateTemplate(
	ctx context.Context,
	trainerID uuid.UUID,
	name, description string,
	durationMinutes int,
	equipment []string,
	levelOfPreparation string,
	photoPath *string,
	galleryPhotoIDs []uuid.UUID,
	maxPeopleCount int,
	groupTypeID uuid.UUID,
	isActive bool,
) (*domain.GroupTrainingTemplate, error) {
	if name == "" {
		return nil, errors.New("template name is required")
	}
	galleryPhotoIDs = dedupeGalleryPhotoIDs(galleryPhotoIDs)
	if len(galleryPhotoIDs) > domain.MaxPhotosPerGroupTrainingTemplate {
		return nil, domain.ErrGroupTrainingTemplateTooManyPhotos
	}
	return uc.templates.Create(ctx, trainerID, name, description, durationMinutes, equipment, levelOfPreparation, photoPath, galleryPhotoIDs, maxPeopleCount, groupTypeID, isActive)
}

func (uc *GroupTrainingUseCase) ListTrainerTemplates(ctx context.Context, trainerID uuid.UUID, limit, offset int) ([]*domain.GroupTrainingTemplate, error) {
	return uc.templates.ListByTrainerID(ctx, trainerID, limit, offset)
}

func (uc *GroupTrainingUseCase) GetTrainerTemplate(ctx context.Context, trainerID, templateID uuid.UUID) (*domain.GroupTrainingTemplate, error) {
	return uc.templates.GetByID(ctx, trainerID, templateID)
}

func (uc *GroupTrainingUseCase) UpdateTemplate(
	ctx context.Context,
	trainerID, templateID uuid.UUID,
	name, description string,
	durationMinutes int,
	equipment []string,
	levelOfPreparation string,
	photoPath *string,
	galleryPhotoIDs []uuid.UUID,
	maxPeopleCount int,
	groupTypeID uuid.UUID,
	isActive bool,
) (*domain.GroupTrainingTemplate, error) {
	galleryPhotoIDs = dedupeGalleryPhotoIDs(galleryPhotoIDs)
	if len(galleryPhotoIDs) > domain.MaxPhotosPerGroupTrainingTemplate {
		return nil, domain.ErrGroupTrainingTemplateTooManyPhotos
	}
	return uc.templates.Update(ctx, trainerID, templateID, name, description, durationMinutes, equipment, levelOfPreparation, photoPath, galleryPhotoIDs, maxPeopleCount, groupTypeID, isActive)
}

func (uc *GroupTrainingUseCase) SoftDeleteTemplate(ctx context.Context, trainerID, templateID uuid.UUID) error {
	return uc.templates.SoftDelete(ctx, trainerID, templateID)
}

func (uc *GroupTrainingUseCase) CreateTraining(ctx context.Context, trainerID, templateID, gymID uuid.UUID, scheduledAt time.Time) (*domain.GroupTraining, error) {
	// Free user limit: at most 3 created group trainings per week.
	userRec, err := uc.users.GetByID(ctx, trainerID)
	if err != nil {
		return nil, err
	}
	if !userRec.PaidSubscriber {
		now := time.Now().UTC()
		weekStart := startOfWeekUTC(now)
		weekEnd := weekStart.AddDate(0, 0, 7)
		n, err := uc.trainings.CountTrainerCreationsInWeek(ctx, trainerID, weekStart, weekEnd)
		if err != nil {
			return nil, err
		}
		if n >= 3 {
			return nil, domain.ErrFreeUserWeeklyLimitReached
		}
	}

	return uc.trainings.Create(ctx, trainerID, templateID, scheduledAt, gymID)
}

func (uc *GroupTrainingUseCase) UpdateTraining(
	ctx context.Context,
	trainerID,
	trainingID,
	templateID,
	gymID uuid.UUID,
	scheduledAt time.Time,
) (*domain.GroupTraining, error) {
	return uc.trainings.Update(ctx, trainerID, trainingID, templateID, scheduledAt, gymID)
}

func (uc *GroupTrainingUseCase) ListTrainerTrainings(ctx context.Context, trainerID uuid.UUID, includePast bool, limit, offset int) ([]*domain.GroupTraining, error) {
	return uc.trainings.ListByTrainerID(ctx, trainerID, includePast, limit, offset)
}

func (uc *GroupTrainingUseCase) ListUserTrainings(ctx context.Context, userID uuid.UUID, includePast bool, limit, offset int) ([]*domain.GroupTraining, error) {
	return uc.trainings.ListByUserID(ctx, userID, includePast, limit, offset)
}

func (uc *GroupTrainingUseCase) GetTrainingForTrainer(ctx context.Context, trainerID, trainingID uuid.UUID) (*domain.GroupTraining, error) {
	return uc.trainings.GetByIDForTrainer(ctx, trainerID, trainingID)
}

func (uc *GroupTrainingUseCase) GetTrainingForUser(ctx context.Context, userID, trainingID uuid.UUID) (*domain.GroupTraining, error) {
	return uc.trainings.GetByIDForUser(ctx, userID, trainingID)
}

func (uc *GroupTrainingUseCase) ListParticipantsForTrainer(ctx context.Context, trainerID, trainingID uuid.UUID) ([]*domain.ParticipantProfile, error) {
	// Ownership check
	if _, err := uc.trainings.GetByIDForTrainer(ctx, trainerID, trainingID); err != nil {
		return nil, err
	}
	return uc.registrations.ListParticipantsByTrainingID(ctx, trainingID)
}

func (uc *GroupTrainingUseCase) ListParticipantsForUser(ctx context.Context, userID, trainingID uuid.UUID) ([]*domain.ParticipantProfile, error) {
	// User must be registered for the training
	if _, err := uc.trainings.GetByIDForUser(ctx, userID, trainingID); err != nil {
		return nil, err
	}
	return uc.registrations.ListParticipantsByTrainingID(ctx, trainingID)
}

func (uc *GroupTrainingUseCase) DeleteTraining(ctx context.Context, trainerID, trainingID uuid.UUID) error {
	return uc.trainings.Delete(ctx, trainerID, trainingID)
}

func (uc *GroupTrainingUseCase) ListAvailableForUser(
	ctx context.Context,
	userID uuid.UUID,
	city *string,
	gymID *uuid.UUID,
	trainerUserID *uuid.UUID,
	dateFrom *time.Time,
	dateTo *time.Time,
	groupTypeID *uuid.UUID,
	limit, offset int,
) ([]*domain.GroupTrainingBookingItem, error) {
	return uc.trainings.ListAvailableForUser(ctx, userID, city, gymID, trainerUserID, dateFrom, dateTo, groupTypeID, limit, offset)
}

// ListUpcomingForTrainer returns future group trainings created by a trainer.
func (uc *GroupTrainingUseCase) ListUpcomingForTrainer(
	ctx context.Context,
	trainerID uuid.UUID,
	limit, offset int,
) ([]*domain.GroupTrainingBookingItem, error) {
	return uc.trainings.ListUpcomingForTrainer(ctx, trainerID, limit, offset)
}

// GetTrainingBookingDisplay returns rich card data for a training (for detail screens).
func (uc *GroupTrainingUseCase) GetTrainingBookingDisplay(ctx context.Context, trainingID uuid.UUID) (*domain.GroupTrainingBookingItem, error) {
	return uc.trainings.GetBookingDisplayByID(ctx, trainingID)
}

// GetPublicTrainingLanding returns display data for a future group training (public share link).
func (uc *GroupTrainingUseCase) GetPublicTrainingLanding(ctx context.Context, trainingID uuid.UUID) (*domain.GroupTrainingBookingItem, error) {
	item, err := uc.trainings.GetBookingDisplayByID(ctx, trainingID)
	if err != nil {
		return nil, err
	}
	if item.ScheduledAt.Before(time.Now().UTC()) {
		return nil, domain.ErrGroupTrainingNotFound
	}
	return item, nil
}

func startOfWeekUTC(now time.Time) time.Time {
	// ISO-style: Monday 00:00:00
	weekday := int(now.Weekday())
	// Sunday=0 -> shift to 7
	if weekday == 0 {
		weekday = 7
	}
	// days since Monday
	daysSinceMonday := weekday - 1
	d := time.Date(now.Year(), now.Month(), now.Day(), 0, 0, 0, 0, time.UTC).AddDate(0, 0, -daysSinceMonday)
	return d
}

func (uc *GroupTrainingUseCase) RegisterUser(ctx context.Context, userID, trainingID uuid.UUID) error {
	already, err := uc.registrations.IsRegistered(ctx, userID, trainingID)
	if err != nil {
		return err
	}
	if already {
		return domain.ErrRegistrationAlreadyExists
	}

	// Capacity check.
	maxPeople, err := uc.trainings.GetMaxPeopleForTraining(ctx, trainingID)
	if err != nil {
		return err
	}
	current, err := uc.registrations.CountByTrainingID(ctx, trainingID)
	if err != nil {
		return err
	}
	if current >= maxPeople {
		return domain.ErrGroupTrainingFull
	}

	return uc.registrations.Add(ctx, userID, trainingID)
}

func (uc *GroupTrainingUseCase) UnregisterUser(ctx context.Context, userID, trainingID uuid.UUID) error {
	return uc.registrations.Delete(ctx, userID, trainingID)
}

// getMaxPeopleForTraining fetches template capacity for a given training.
// (capacity retrieval is implemented in training repository)

// ListGroupTrainingsByGym returns group trainings at a gym (scheduled ascending).
func (uc *GroupTrainingUseCase) ListGroupTrainingsByGym(ctx context.Context, gymID uuid.UUID, limit, offset int) ([]*domain.GroupTraining, error) {
	return uc.trainings.ListByGymID(ctx, gymID, limit, offset)
}

// ListTrainersAtGym returns trainers who run group trainings or personal workouts at the gym.
func (uc *GroupTrainingUseCase) ListTrainersAtGym(ctx context.Context, gymID uuid.UUID) ([]domain.TrainerAtGym, error) {
	return uc.trainings.ListTrainersAtGym(ctx, gymID)
}

