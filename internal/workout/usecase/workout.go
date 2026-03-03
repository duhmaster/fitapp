package usecase

import (
	"context"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
)

type WorkoutUseCase struct {
	exercises   workoutdomain.ExerciseRepository
	workouts    workoutdomain.WorkoutRepository
	woExercises workoutdomain.WorkoutExerciseRepository
	logs        workoutdomain.ExerciseLogRepository
}

func NewWorkoutUseCase(
	exercises workoutdomain.ExerciseRepository,
	workouts workoutdomain.WorkoutRepository,
	woExercises workoutdomain.WorkoutExerciseRepository,
	logs workoutdomain.ExerciseLogRepository,
) *WorkoutUseCase {
	return &WorkoutUseCase{
		exercises:   exercises,
		workouts:    workouts,
		woExercises: woExercises,
		logs:        logs,
	}
}

func (uc *WorkoutUseCase) ListExercises(ctx context.Context, limit, offset int) ([]*workoutdomain.Exercise, error) {
	return uc.exercises.List(ctx, limit, offset)
}

func (uc *WorkoutUseCase) CreateWorkout(ctx context.Context, user *authdomain.User, templateID *uuid.UUID, scheduledAt *time.Time) (*workoutdomain.Workout, error) {
	return uc.workouts.Create(ctx, user.ID, templateID, scheduledAt)
}

func (uc *WorkoutUseCase) ListMyWorkouts(ctx context.Context, user *authdomain.User, limit, offset int) ([]*workoutdomain.Workout, error) {
	return uc.workouts.ListByUserID(ctx, user.ID, limit, offset)
}

func (uc *WorkoutUseCase) GetWorkout(ctx context.Context, user *authdomain.User, workoutID uuid.UUID) (*workoutdomain.Workout, error) {
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if w.UserID != user.ID {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	return w, nil
}

func (uc *WorkoutUseCase) StartWorkout(ctx context.Context, user *authdomain.User, workoutID uuid.UUID, at time.Time) (*workoutdomain.Workout, error) {
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if w.UserID != user.ID {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	return uc.workouts.Start(ctx, workoutID, at)
}

func (uc *WorkoutUseCase) FinishWorkout(ctx context.Context, user *authdomain.User, workoutID uuid.UUID, at time.Time) (*workoutdomain.Workout, error) {
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if w.UserID != user.ID {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	return uc.workouts.Finish(ctx, workoutID, at)
}

func (uc *WorkoutUseCase) AddExerciseToWorkout(ctx context.Context, user *authdomain.User, workoutID, exerciseID uuid.UUID, sets, reps *int, weightKg *float64, orderIndex int) (*workoutdomain.WorkoutExercise, error) {
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if w.UserID != user.ID {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	if _, err := uc.exercises.GetByID(ctx, exerciseID); err != nil {
		return nil, err
	}
	return uc.woExercises.Create(ctx, workoutID, exerciseID, sets, reps, weightKg, orderIndex)
}

func (uc *WorkoutUseCase) LogSet(ctx context.Context, user *authdomain.User, workoutID, exerciseID uuid.UUID, setNumber int, reps *int, weightKg *float64, restSeconds *int) (*workoutdomain.ExerciseLog, error) {
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if w.UserID != user.ID {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	return uc.logs.Create(ctx, workoutID, exerciseID, setNumber, reps, weightKg, restSeconds)
}

func (uc *WorkoutUseCase) GetWorkoutExercises(ctx context.Context, user *authdomain.User, workoutID uuid.UUID) ([]*workoutdomain.WorkoutExercise, error) {
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if w.UserID != user.ID {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	return uc.woExercises.ListByWorkoutID(ctx, workoutID)
}

func (uc *WorkoutUseCase) GetWorkoutLogs(ctx context.Context, user *authdomain.User, workoutID uuid.UUID) ([]*workoutdomain.ExerciseLog, error) {
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if w.UserID != user.ID {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	return uc.logs.ListByWorkoutID(ctx, workoutID)
}
