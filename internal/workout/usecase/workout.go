package usecase

import (
	"context"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
)

type WorkoutUseCase struct {
	exercises         workoutdomain.ExerciseRepository
	workouts          workoutdomain.WorkoutRepository
	woExercises       workoutdomain.WorkoutExerciseRepository
	logs              workoutdomain.ExerciseLogRepository
	programs          workoutdomain.ProgramRepository
	programExercises  workoutdomain.ProgramExerciseRepository
}

func NewWorkoutUseCase(
	exercises workoutdomain.ExerciseRepository,
	workouts workoutdomain.WorkoutRepository,
	woExercises workoutdomain.WorkoutExerciseRepository,
	logs workoutdomain.ExerciseLogRepository,
	programs workoutdomain.ProgramRepository,
	programExercises workoutdomain.ProgramExerciseRepository,
) *WorkoutUseCase {
	return &WorkoutUseCase{
		exercises:        exercises,
		workouts:         workouts,
		woExercises:      woExercises,
		logs:             logs,
		programs:         programs,
		programExercises: programExercises,
	}
}

func (uc *WorkoutUseCase) ListExercises(ctx context.Context, limit, offset int, filters *workoutdomain.ExerciseFilters) ([]*workoutdomain.Exercise, error) {
	return uc.exercises.List(ctx, limit, offset, filters)
}

func (uc *WorkoutUseCase) CreateWorkout(ctx context.Context, user *authdomain.User, templateID *uuid.UUID, programID *uuid.UUID, scheduledAt *time.Time) (*workoutdomain.Workout, error) {
	return uc.workouts.Create(ctx, user.ID, templateID, programID, scheduledAt)
}

func (uc *WorkoutUseCase) ListPrograms(ctx context.Context, user *authdomain.User, limit, offset int) ([]*workoutdomain.Program, error) {
	var uid *uuid.UUID
	if user != nil {
		uid = &user.ID
	}
	return uc.programs.List(ctx, uid, limit, offset)
}

func (uc *WorkoutUseCase) CreateProgram(ctx context.Context, user *authdomain.User, name, description string) (*workoutdomain.Program, error) {
	return uc.programs.Create(ctx, name, description, &user.ID)
}

func (uc *WorkoutUseCase) GetProgramExercises(ctx context.Context, programID uuid.UUID) ([]*workoutdomain.ProgramExercise, error) {
	return uc.programExercises.ListByProgramID(ctx, programID)
}

func (uc *WorkoutUseCase) StartWorkoutFromProgram(ctx context.Context, user *authdomain.User, programID uuid.UUID, scheduledAt *time.Time) (*workoutdomain.Workout, error) {
	if _, err := uc.programs.GetByID(ctx, programID); err != nil {
		return nil, err
	}
	w, err := uc.workouts.Create(ctx, user.ID, nil, &programID, scheduledAt)
	if err != nil {
		return nil, err
	}
	pes, err := uc.programExercises.ListByProgramID(ctx, programID)
	if err != nil {
		return nil, err
	}
	for i, pe := range pes {
		_, err := uc.woExercises.Create(ctx, w.ID, pe.ExerciseID, nil, nil, nil, pe.OrderIndex)
		if err != nil {
			return nil, err
		}
		_ = i
	}
	return w, nil
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
