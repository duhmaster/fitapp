package domain

import (
	"context"

	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
)

type Repository interface {
	EnqueueWorkoutFeedback(ctx context.Context, userID, workoutID uuid.UUID, feedback *workoutdomain.WorkoutFeedback) error
	ProcessOutbox(ctx context.Context, limit int) (int, error)
	ListByUserID(ctx context.Context, userID uuid.UUID, limit int) ([]*Recommendation, error)
}
