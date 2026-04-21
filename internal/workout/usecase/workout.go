package usecase

import (
	"context"
	"errors"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// TrainerClientChecker allows workout usecase to verify trainer–client relationship (optional).
type TrainerClientChecker interface {
	IsClientOfTrainer(ctx context.Context, trainerID, clientID uuid.UUID) (bool, error)
}

type WorkoutUseCase struct {
	exercises             workoutdomain.ExerciseRepository
	workouts              workoutdomain.WorkoutRepository
	feedbacks             workoutdomain.WorkoutFeedbackRepository
	woExercises           workoutdomain.WorkoutExerciseRepository
	logs                  workoutdomain.ExerciseLogRepository
	programs              workoutdomain.ProgramRepository
	programExercises      workoutdomain.ProgramExerciseRepository
	templates             workoutdomain.WorkoutTemplateRepository
	templateExercises     workoutdomain.WorkoutTemplateExerciseRepository
	templateSets          workoutdomain.TemplateExerciseSetRepository
	trainerChecker        TrainerClientChecker
	gamificationOnFinish  func(ctx context.Context, userID, workoutID uuid.UUID, volumeKg float64) error
	finishPool            *pgxpool.Pool
	gamEnqueue            func(ctx context.Context, tx pgx.Tx, userID, workoutID uuid.UUID, volumeKg float64) error
	gamProcess            func(ctx context.Context) error
	recommendationEnqueue func(ctx context.Context, userID, workoutID uuid.UUID, feedback *workoutdomain.WorkoutFeedback) error
}

func NewWorkoutUseCase(
	exercises workoutdomain.ExerciseRepository,
	workouts workoutdomain.WorkoutRepository,
	woExercises workoutdomain.WorkoutExerciseRepository,
	logs workoutdomain.ExerciseLogRepository,
	programs workoutdomain.ProgramRepository,
	programExercises workoutdomain.ProgramExerciseRepository,
	templates workoutdomain.WorkoutTemplateRepository,
	templateExercises workoutdomain.WorkoutTemplateExerciseRepository,
	templateSets workoutdomain.TemplateExerciseSetRepository,
) *WorkoutUseCase {
	return &WorkoutUseCase{
		exercises:         exercises,
		workouts:          workouts,
		woExercises:       woExercises,
		logs:              logs,
		programs:          programs,
		programExercises:  programExercises,
		templates:         templates,
		templateExercises: templateExercises,
		templateSets:      templateSets,
	}
}

// SetTrainerChecker sets optional checker so trainers can view their trainees' workouts.
func (uc *WorkoutUseCase) SetTrainerChecker(c TrainerClientChecker) {
	uc.trainerChecker = c
}

// SetGamificationOnFinish registers a callback after a workout is finished successfully (volume = sum reps×weight from logs). Errors are ignored.
// Ignored when SetGamificationOutbox is configured (outbox + same-request processing).
func (uc *WorkoutUseCase) SetGamificationOnFinish(h func(ctx context.Context, userID, workoutID uuid.UUID, volumeKg float64) error) {
	uc.gamificationOnFinish = h
}

// SetGamificationOutbox enqueues workout XP in the same DB transaction as Finish, then runs processing (ledger + Redis).
func (uc *WorkoutUseCase) SetGamificationOutbox(pool *pgxpool.Pool, enqueue func(ctx context.Context, tx pgx.Tx, userID, workoutID uuid.UUID, volumeKg float64) error, process func(ctx context.Context) error) {
	uc.finishPool = pool
	uc.gamEnqueue = enqueue
	uc.gamProcess = process
}

func (uc *WorkoutUseCase) SetWorkoutFeedbackRepository(repo workoutdomain.WorkoutFeedbackRepository) {
	uc.feedbacks = repo
}

func (uc *WorkoutUseCase) SetRecommendationEnqueue(enqueue func(ctx context.Context, userID, workoutID uuid.UUID, feedback *workoutdomain.WorkoutFeedback) error) {
	uc.recommendationEnqueue = enqueue
}

func (uc *WorkoutUseCase) canAccessWorkout(ctx context.Context, user *authdomain.User, workoutUserID uuid.UUID) bool {
	if user.ID == workoutUserID {
		return true
	}
	if uc.trainerChecker != nil {
		ok, _ := uc.trainerChecker.IsClientOfTrainer(ctx, user.ID, workoutUserID)
		return ok
	}
	return false
}

func (uc *WorkoutUseCase) ListExercises(ctx context.Context, limit, offset int, filters *workoutdomain.ExerciseFilters) ([]*workoutdomain.Exercise, error) {
	return uc.exercises.List(ctx, limit, offset, filters)
}

func (uc *WorkoutUseCase) CreateWorkout(ctx context.Context, user *authdomain.User, trainerID *uuid.UUID, templateID *uuid.UUID, programID *uuid.UUID, scheduledAt *time.Time, gymID *uuid.UUID) (*workoutdomain.Workout, error) {
	w, err := uc.workouts.Create(ctx, user.ID, trainerID, templateID, programID, scheduledAt, gymID)
	if err != nil {
		return nil, err
	}
	if templateID != nil {
		tes, err := uc.templateExercises.ListByTemplateID(ctx, *templateID)
		if err != nil {
			return nil, err
		}
		for _, te := range tes {
			if _, err := uc.woExercises.Create(ctx, w.ID, te.ExerciseID, nil, nil, nil, te.ExerciseOrder); err != nil {
				return nil, err
			}
		}
	}
	return w, nil
}

// CreateWorkoutForClient creates a workout for a client; trainer must be the client's trainer.
func (uc *WorkoutUseCase) CreateWorkoutForClient(ctx context.Context, trainer *authdomain.User, clientID uuid.UUID, templateID *uuid.UUID, scheduledAt *time.Time, gymID *uuid.UUID) (*workoutdomain.Workout, error) {
	if uc.trainerChecker == nil {
		return nil, errors.New("trainer checker not configured")
	}
	ok, err := uc.trainerChecker.IsClientOfTrainer(ctx, trainer.ID, clientID)
	if err != nil || !ok {
		return nil, errors.New("client not found or access denied")
	}
	trainerID := trainer.ID
	w, err := uc.workouts.Create(ctx, clientID, &trainerID, templateID, nil, scheduledAt, gymID)
	if err != nil {
		return nil, err
	}
	if templateID != nil {
		tes, err := uc.templateExercises.ListByTemplateID(ctx, *templateID)
		if err != nil {
			return nil, err
		}
		for _, te := range tes {
			if _, err := uc.woExercises.Create(ctx, w.ID, te.ExerciseID, nil, nil, nil, te.ExerciseOrder); err != nil {
				return nil, err
			}
		}
	}
	return w, nil
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
	w, err := uc.workouts.Create(ctx, user.ID, nil, nil, &programID, scheduledAt, nil)
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

func (uc *WorkoutUseCase) ListMyWorkouts(ctx context.Context, user *authdomain.User, limit, offset int, finishedFrom, finishedTo *time.Time) ([]*workoutdomain.Workout, error) {
	return uc.workouts.ListByUserID(ctx, user.ID, limit, offset, finishedFrom, finishedTo)
}

func (uc *WorkoutUseCase) ListWorkoutsByTrainerID(ctx context.Context, trainerID uuid.UUID, limit, offset int) ([]*workoutdomain.Workout, error) {
	return uc.workouts.ListByTrainerID(ctx, trainerID, limit, offset)
}

func (uc *WorkoutUseCase) CountByTrainerID(ctx context.Context, trainerID uuid.UUID) (int, error) {
	return uc.workouts.CountByTrainerID(ctx, trainerID)
}

func (uc *WorkoutUseCase) GetWorkout(ctx context.Context, user *authdomain.User, workoutID uuid.UUID) (*workoutdomain.Workout, error) {
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if !uc.canAccessWorkout(ctx, user, w.UserID) {
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

	logs, logErr := uc.logs.ListByWorkoutID(ctx, workoutID)
	var volume float64
	if logErr == nil {
		for _, l := range logs {
			if l.Reps != nil && l.WeightKg != nil && *l.Reps > 0 {
				volume += float64(*l.Reps) * *l.WeightKg
			}
		}
	}

	if uc.finishPool != nil && uc.gamEnqueue != nil {
		tx, err := uc.finishPool.Begin(ctx)
		if err != nil {
			return nil, err
		}
		defer func() { _ = tx.Rollback(ctx) }()
		w, err = uc.workouts.FinishTx(ctx, tx, workoutID, at)
		if err != nil {
			return nil, err
		}
		if err := uc.gamEnqueue(ctx, tx, user.ID, workoutID, volume); err != nil {
			return nil, err
		}
		if err := tx.Commit(ctx); err != nil {
			return nil, err
		}
		if uc.gamProcess != nil {
			_ = uc.gamProcess(ctx)
		}
		return w, nil
	}

	w, err = uc.workouts.Finish(ctx, workoutID, at)
	if err != nil {
		return nil, err
	}
	if uc.gamificationOnFinish != nil && logErr == nil {
		_ = uc.gamificationOnFinish(ctx, user.ID, workoutID, volume)
	}
	return w, nil
}

func (uc *WorkoutUseCase) UpsertWorkoutFeedback(ctx context.Context, user *authdomain.User, feedback *workoutdomain.WorkoutFeedback) (*workoutdomain.WorkoutFeedback, error) {
	if uc.feedbacks == nil {
		return nil, errors.New("workout feedback repository not configured")
	}
	w, err := uc.workouts.GetByID(ctx, feedback.WorkoutID)
	if err != nil {
		return nil, err
	}
	if w.UserID != user.ID {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	if w.FinishedAt == nil {
		return nil, workoutdomain.ErrWorkoutFeedbackInvalid
	}

	if feedback.SessionQuality < 1 || feedback.SessionQuality > 5 {
		return nil, workoutdomain.ErrWorkoutFeedbackInvalid
	}
	if feedback.OverallWellbeing < 1 || feedback.OverallWellbeing > 5 {
		return nil, workoutdomain.ErrWorkoutFeedbackInvalid
	}
	if feedback.Fatigue < 1 || feedback.Fatigue > 10 {
		return nil, workoutdomain.ErrWorkoutFeedbackInvalid
	}
	if feedback.MuscleSoreness != nil && (*feedback.MuscleSoreness < 0 || *feedback.MuscleSoreness > 10) {
		return nil, workoutdomain.ErrWorkoutFeedbackInvalid
	}
	if feedback.PainDiscomfort != nil && (*feedback.PainDiscomfort < 0 || *feedback.PainDiscomfort > 10) {
		return nil, workoutdomain.ErrWorkoutFeedbackInvalid
	}
	if feedback.StressLevel != nil && (*feedback.StressLevel < 1 || *feedback.StressLevel > 5) {
		return nil, workoutdomain.ErrWorkoutFeedbackInvalid
	}
	if feedback.SleepHours != nil && (*feedback.SleepHours < 0 || *feedback.SleepHours > 24) {
		return nil, workoutdomain.ErrWorkoutFeedbackInvalid
	}
	if feedback.SleepQuality != nil && (*feedback.SleepQuality < 1 || *feedback.SleepQuality > 5) {
		return nil, workoutdomain.ErrWorkoutFeedbackInvalid
	}

	feedback.UserID = user.ID
	saved, err := uc.feedbacks.Upsert(ctx, feedback)
	if err != nil {
		return nil, err
	}
	if uc.recommendationEnqueue != nil {
		_ = uc.recommendationEnqueue(ctx, user.ID, feedback.WorkoutID, saved)
	}
	return saved, nil
}

func (uc *WorkoutUseCase) GetWorkoutFeedback(ctx context.Context, user *authdomain.User, workoutID uuid.UUID) (*workoutdomain.WorkoutFeedback, error) {
	if uc.feedbacks == nil {
		return nil, nil
	}
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if !uc.canAccessWorkout(ctx, user, w.UserID) {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	return uc.feedbacks.GetByWorkoutID(ctx, workoutID)
}

func (uc *WorkoutUseCase) DeleteWorkout(ctx context.Context, user *authdomain.User, workoutID uuid.UUID) error {
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return err
	}
	if w.UserID != user.ID {
		return workoutdomain.ErrWorkoutForbidden
	}
	return uc.workouts.Delete(ctx, workoutID)
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
	if !uc.canAccessWorkout(ctx, user, w.UserID) {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	return uc.woExercises.ListByWorkoutID(ctx, workoutID)
}

func (uc *WorkoutUseCase) GetWorkoutLogs(ctx context.Context, user *authdomain.User, workoutID uuid.UUID) ([]*workoutdomain.ExerciseLog, error) {
	w, err := uc.workouts.GetByID(ctx, workoutID)
	if err != nil {
		return nil, err
	}
	if !uc.canAccessWorkout(ctx, user, w.UserID) {
		return nil, workoutdomain.ErrWorkoutForbidden
	}
	return uc.logs.ListByWorkoutID(ctx, workoutID)
}

// --- Workout templates ---

func (uc *WorkoutUseCase) ListTemplates(ctx context.Context, user *authdomain.User, limit, offset int) ([]*workoutdomain.WorkoutTemplate, error) {
	return uc.templates.ListByUserID(ctx, user.ID, limit, offset)
}

func (uc *WorkoutUseCase) CountTemplateExercises(ctx context.Context, user *authdomain.User, templateID uuid.UUID) (int, error) {
	if _, err := uc.GetTemplate(ctx, user, templateID); err != nil {
		return 0, err
	}
	return uc.templates.CountExercises(ctx, templateID)
}

func (uc *WorkoutUseCase) GetTemplate(ctx context.Context, user *authdomain.User, templateID uuid.UUID) (*workoutdomain.WorkoutTemplate, error) {
	t, err := uc.templates.GetByID(ctx, templateID)
	if err != nil {
		return nil, err
	}
	if !uc.canAccessWorkout(ctx, user, t.CreatedBy) {
		return nil, workoutdomain.ErrTemplateForbidden
	}
	return t, nil
}

func (uc *WorkoutUseCase) GetTemplateWithExercises(ctx context.Context, user *authdomain.User, templateID uuid.UUID) (*workoutdomain.WorkoutTemplate, []*workoutdomain.WorkoutTemplateExercise, error) {
	t, err := uc.GetTemplate(ctx, user, templateID)
	if err != nil {
		return nil, nil, err
	}
	tes, err := uc.templateExercises.ListByTemplateID(ctx, templateID)
	if err != nil {
		return nil, nil, err
	}
	for _, te := range tes {
		ex, _ := uc.exercises.GetByID(ctx, te.ExerciseID)
		te.Exercise = ex
		sets, _ := uc.templateSets.ListByTemplateExerciseID(ctx, te.ID)
		te.Sets = sets
	}
	return t, tes, nil
}

func (uc *WorkoutUseCase) CreateTemplate(ctx context.Context, user *authdomain.User, name string, useRestTimer bool, restSeconds int) (*workoutdomain.WorkoutTemplate, error) {
	return uc.templates.Create(ctx, name, user.ID, useRestTimer, restSeconds)
}

// CreateTemplateForClient creates a workout template for a trainee. Caller must be the client's trainer.
func (uc *WorkoutUseCase) CreateTemplateForClient(ctx context.Context, trainer *authdomain.User, clientID uuid.UUID, name string, useRestTimer bool, restSeconds int) (*workoutdomain.WorkoutTemplate, error) {
	if uc.trainerChecker == nil {
		return nil, workoutdomain.ErrTemplateForbidden
	}
	ok, err := uc.trainerChecker.IsClientOfTrainer(ctx, trainer.ID, clientID)
	if err != nil || !ok {
		return nil, workoutdomain.ErrTemplateForbidden
	}
	return uc.templates.Create(ctx, name, clientID, useRestTimer, restSeconds)
}

// ListTemplatesForClient returns a trainee's templates. Caller must be the client's trainer.
func (uc *WorkoutUseCase) ListTemplatesForClient(ctx context.Context, trainer *authdomain.User, clientID uuid.UUID, limit, offset int) ([]*workoutdomain.WorkoutTemplate, error) {
	if uc.trainerChecker == nil {
		return nil, workoutdomain.ErrTemplateForbidden
	}
	ok, err := uc.trainerChecker.IsClientOfTrainer(ctx, trainer.ID, clientID)
	if err != nil || !ok {
		return nil, workoutdomain.ErrTemplateForbidden
	}
	return uc.templates.ListByUserID(ctx, clientID, limit, offset)
}

func (uc *WorkoutUseCase) UpdateTemplate(ctx context.Context, user *authdomain.User, templateID uuid.UUID, name string, useRestTimer bool, restSeconds int) (*workoutdomain.WorkoutTemplate, error) {
	if _, err := uc.GetTemplate(ctx, user, templateID); err != nil {
		return nil, err
	}
	return uc.templates.Update(ctx, templateID, name, useRestTimer, restSeconds)
}

func (uc *WorkoutUseCase) DeleteTemplate(ctx context.Context, user *authdomain.User, templateID uuid.UUID) error {
	if _, err := uc.GetTemplate(ctx, user, templateID); err != nil {
		return err
	}
	return uc.templates.SoftDelete(ctx, templateID)
}

func (uc *WorkoutUseCase) AddExerciseToTemplate(ctx context.Context, user *authdomain.User, templateID, exerciseID uuid.UUID, order int) (*workoutdomain.WorkoutTemplateExercise, error) {
	if _, err := uc.GetTemplate(ctx, user, templateID); err != nil {
		return nil, err
	}
	if _, err := uc.exercises.GetByID(ctx, exerciseID); err != nil {
		return nil, err
	}
	return uc.templateExercises.Create(ctx, templateID, exerciseID, order)
}

func (uc *WorkoutUseCase) RemoveExerciseFromTemplate(ctx context.Context, user *authdomain.User, templateExerciseID uuid.UUID) error {
	te, err := uc.templateExercises.GetByID(ctx, templateExerciseID)
	if err != nil {
		return err
	}
	if _, err := uc.GetTemplate(ctx, user, te.TemplateID); err != nil {
		return err
	}
	_ = uc.templateSets.DeleteByTemplateExerciseID(ctx, templateExerciseID)
	return uc.templateExercises.Delete(ctx, templateExerciseID)
}

func (uc *WorkoutUseCase) ReorderTemplateExercises(ctx context.Context, user *authdomain.User, templateID uuid.UUID, orderedIDs []uuid.UUID) error {
	if _, err := uc.GetTemplate(ctx, user, templateID); err != nil {
		return err
	}
	return uc.templateExercises.Reorder(ctx, templateID, orderedIDs)
}

func (uc *WorkoutUseCase) AddSetToTemplateExercise(ctx context.Context, user *authdomain.User, templateExerciseID uuid.UUID, setOrder int, weightKg *float64, reps *int) (*workoutdomain.TemplateExerciseSet, error) {
	te, err := uc.templateExercises.GetByID(ctx, templateExerciseID)
	if err != nil {
		return nil, err
	}
	if _, err := uc.GetTemplate(ctx, user, te.TemplateID); err != nil {
		return nil, err
	}
	return uc.templateSets.Create(ctx, templateExerciseID, setOrder, weightKg, reps)
}

func (uc *WorkoutUseCase) DeleteTemplateSet(ctx context.Context, user *authdomain.User, templateExerciseID, setID uuid.UUID) error {
	te, err := uc.templateExercises.GetByID(ctx, templateExerciseID)
	if err != nil {
		return err
	}
	if _, err := uc.GetTemplate(ctx, user, te.TemplateID); err != nil {
		return err
	}
	return uc.templateSets.DeleteByIDAndTemplateExerciseID(ctx, setID, templateExerciseID)
}

func (uc *WorkoutUseCase) StartWorkoutFromTemplate(ctx context.Context, user *authdomain.User, templateID uuid.UUID, scheduledAt *time.Time) (*workoutdomain.Workout, error) {
	t, err := uc.GetTemplate(ctx, user, templateID)
	if err != nil {
		return nil, err
	}
	w, err := uc.workouts.Create(ctx, user.ID, nil, &t.ID, nil, scheduledAt, nil)
	if err != nil {
		return nil, err
	}
	tes, err := uc.templateExercises.ListByTemplateID(ctx, templateID)
	if err != nil {
		return nil, err
	}
	for i, te := range tes {
		_, err := uc.woExercises.Create(ctx, w.ID, te.ExerciseID, nil, nil, nil, i)
		if err != nil {
			return nil, err
		}
		// Planned sets come from template; logs are created when user saves/skips a set
	}
	return uc.workouts.Start(ctx, w.ID, time.Now().UTC())
}

// ListUserExerciseIDsForProgress returns exercise IDs that appear in user's workout logs.
func (uc *WorkoutUseCase) ListUserExerciseIDsForProgress(ctx context.Context, user *authdomain.User) ([]uuid.UUID, error) {
	return uc.logs.ListDistinctExerciseIDsForUser(ctx, user.ID)
}

// ListExerciseVolumeHistoryForProgress returns per-workout volume for an exercise.
func (uc *WorkoutUseCase) ListExerciseVolumeHistoryForProgress(ctx context.Context, user *authdomain.User, exerciseID uuid.UUID) ([]workoutdomain.ExerciseVolumeEntry, error) {
	return uc.logs.ListVolumeHistoryByExerciseForUser(ctx, user.ID, exerciseID)
}
