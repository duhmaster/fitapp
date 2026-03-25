package domain

import (
	"context"
	"time"

	"github.com/google/uuid"
)

type GroupTrainingTypeRepository interface {
	List(ctx context.Context) ([]*GroupTrainingType, error)
}

type GroupTrainingTemplateRepository interface {
	Create(
		ctx context.Context,
		trainerID uuid.UUID,
		name string,
		description string,
		durationMinutes int,
		equipment []string,
		levelOfPreparation string,
		photoPath *string,
		photoID *uuid.UUID,
		maxPeopleCount int,
		groupTypeID uuid.UUID,
		isActive bool,
	) (*GroupTrainingTemplate, error)

	GetByID(ctx context.Context, trainerID, templateID uuid.UUID) (*GroupTrainingTemplate, error)
	ListByTrainerID(ctx context.Context, trainerID uuid.UUID, limit, offset int) ([]*GroupTrainingTemplate, error)

	Update(
		ctx context.Context,
		trainerID uuid.UUID,
		templateID uuid.UUID,
		name string,
		description string,
		durationMinutes int,
		equipment []string,
		levelOfPreparation string,
		photoPath *string,
		photoID *uuid.UUID,
		maxPeopleCount int,
		groupTypeID uuid.UUID,
		isActive bool,
	) (*GroupTrainingTemplate, error)

	SoftDelete(ctx context.Context, trainerID, templateID uuid.UUID) error
}

type GroupTrainingRepository interface {
	Create(ctx context.Context, trainerID uuid.UUID, templateID uuid.UUID, scheduledAt time.Time, gymID uuid.UUID) (*GroupTraining, error)
	Update(
		ctx context.Context,
		trainerID uuid.UUID,
		trainingID uuid.UUID,
		templateID uuid.UUID,
		scheduledAt time.Time,
		gymID uuid.UUID,
	) (*GroupTraining, error)
	GetByIDForTrainer(ctx context.Context, trainerID, trainingID uuid.UUID) (*GroupTraining, error)
	ListByTrainerID(ctx context.Context, trainerID uuid.UUID, includePast bool, limit, offset int) ([]*GroupTraining, error)

	GetByIDForUser(ctx context.Context, userID, trainingID uuid.UUID) (*GroupTraining, error)
	ListByUserID(ctx context.Context, userID uuid.UUID, includePast bool, limit, offset int) ([]*GroupTraining, error)

	// GetMaxPeopleForTraining returns capacity from template for a training session
	// (only active, not soft-deleted templates are considered bookable).
	GetMaxPeopleForTraining(ctx context.Context, trainingID uuid.UUID) (int, error)

	// GetBookingDisplayByID returns rich display data for a training (active template).
	// Used for public landing and optional detail payloads.
	GetBookingDisplayByID(ctx context.Context, trainingID uuid.UUID) (*GroupTrainingBookingItem, error)

	// ListAvailableForUser returns future, bookable group trainings
	// with remaining capacity, excluding those already registered by the user.
	ListAvailableForUser(
		ctx context.Context,
		userID uuid.UUID,
		city *string,
		gymID *uuid.UUID,
		trainerUserID *uuid.UUID,
		dateFrom *time.Time,
		dateTo *time.Time,
		groupTypeID *uuid.UUID,
		limit, offset int,
	) ([]*GroupTrainingBookingItem, error)

	// ListUpcomingForTrainer returns future group trainings created by a trainer.
	// Includes participants count but does not exclude already registered users (trainer list is public).
	ListUpcomingForTrainer(ctx context.Context, trainerID uuid.UUID, limit, offset int) ([]*GroupTrainingBookingItem, error)

	// CountTrainerCreationsInWeek counts how many group trainings a trainer has created in the given week.
	// Used for limiting free users' group training creation.
	CountTrainerCreationsInWeek(ctx context.Context, trainerID uuid.UUID, weekStart time.Time, weekEnd time.Time) (int, error)

	Delete(ctx context.Context, trainerID uuid.UUID, trainingID uuid.UUID) error
}

type GroupTrainingRegistrationRepository interface {
	CountByTrainingID(ctx context.Context, trainingID uuid.UUID) (int, error)
	ListParticipantsByTrainingID(ctx context.Context, trainingID uuid.UUID) ([]*ParticipantProfile, error)

	Add(ctx context.Context, userID, trainingID uuid.UUID) error
	Delete(ctx context.Context, userID, trainingID uuid.UUID) error

	IsRegistered(ctx context.Context, userID, trainingID uuid.UUID) (bool, error)
	CountUserRegistrationsInWeek(ctx context.Context, userID uuid.UUID, weekStart time.Time, weekEnd time.Time) (int, error)
}

