package delivery

import (
	"net/http"
	"strconv"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	"github.com/fitflow/fitflow/internal/workout/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	uc *usecase.WorkoutUseCase
}

func NewHandler(uc *usecase.WorkoutUseCase) *Handler {
	return &Handler{uc: uc}
}

// ExerciseResponse is the JSON response for an exercise.
type ExerciseResponse struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	MuscleGroup *string `json:"muscle_group,omitempty"`
}

// WorkoutResponse is the JSON response for a workout.
type WorkoutResponse struct {
	ID          string    `json:"id"`
	TemplateID  *string   `json:"template_id,omitempty"`
	UserID      string    `json:"user_id"`
	ScheduledAt *string   `json:"scheduled_at,omitempty"`
	StartedAt   *string   `json:"started_at,omitempty"`
	FinishedAt  *string   `json:"finished_at,omitempty"`
	CreatedAt   string    `json:"created_at"`
}

// WorkoutExerciseResponse is the JSON response for a workout exercise.
type WorkoutExerciseResponse struct {
	ID         string   `json:"id"`
	ExerciseID string   `json:"exercise_id"`
	Sets       *int     `json:"sets,omitempty"`
	Reps       *int     `json:"reps,omitempty"`
	WeightKg   *float64 `json:"weight_kg,omitempty"`
	OrderIndex int      `json:"order_index"`
}

// ExerciseLogResponse is the JSON response for an exercise log.
type ExerciseLogResponse struct {
	ID         string   `json:"id"`
	ExerciseID string   `json:"exercise_id"`
	SetNumber  int      `json:"set_number"`
	Reps       *int     `json:"reps,omitempty"`
	WeightKg   *float64 `json:"weight_kg,omitempty"`
	RestSeconds *int    `json:"rest_seconds,omitempty"`
	LoggedAt   string   `json:"logged_at"`
}

type CreateWorkoutRequest struct {
	TemplateID  *string `json:"template_id"`
	ScheduledAt *string `json:"scheduled_at"`
}

type AddExerciseRequest struct {
	ExerciseID string   `json:"exercise_id" binding:"required"`
	Sets       *int     `json:"sets"`
	Reps       *int     `json:"reps"`
	WeightKg   *float64 `json:"weight_kg"`
	OrderIndex *int     `json:"order_index"`
}

type LogSetRequest struct {
	ExerciseID  string   `json:"exercise_id" binding:"required"`
	SetNumber   int      `json:"set_number" binding:"required"`
	Reps        *int     `json:"reps"`
	WeightKg    *float64 `json:"weight_kg"`
	RestSeconds *int     `json:"rest_seconds"`
}

func (h *Handler) ListExercises(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListExercises(c.Request.Context(), limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]ExerciseResponse, 0, len(list))
	for _, e := range list {
		out = append(out, toExerciseResponse(e))
	}
	c.JSON(http.StatusOK, gin.H{"exercises": out})
}

func (h *Handler) CreateWorkout(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req CreateWorkoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var templateID *uuid.UUID
	if req.TemplateID != nil && *req.TemplateID != "" {
		id, err := uuid.Parse(*req.TemplateID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid template_id"})
			return
		}
		templateID = &id
	}

	var scheduledAt *time.Time
	if req.ScheduledAt != nil && *req.ScheduledAt != "" {
		t, err := time.Parse(time.RFC3339, *req.ScheduledAt)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid scheduled_at"})
			return
		}
		scheduledAt = &t
	}

	w, err := h.uc.CreateWorkout(c.Request.Context(), user, templateID, scheduledAt)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toWorkoutResponse(w))
}

func (h *Handler) ListMyWorkouts(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListMyWorkouts(c.Request.Context(), user, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]WorkoutResponse, 0, len(list))
	for _, w := range list {
		out = append(out, toWorkoutResponse(w))
	}
	c.JSON(http.StatusOK, gin.H{"workouts": out})
}

func (h *Handler) GetWorkout(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	workoutID, ok := parseUUIDParam(c, "workout_id")
	if !ok {
		return
	}

	w, err := h.uc.GetWorkout(c.Request.Context(), user, workoutID)
	if err != nil {
		if err == workoutdomain.ErrWorkoutNotFound || err == workoutdomain.ErrWorkoutForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	exercises, _ := h.uc.GetWorkoutExercises(c.Request.Context(), user, workoutID)
	logs, _ := h.uc.GetWorkoutLogs(c.Request.Context(), user, workoutID)

	exResp := make([]WorkoutExerciseResponse, 0, len(exercises))
	for _, e := range exercises {
		exResp = append(exResp, toWorkoutExerciseResponse(e))
	}
	logResp := make([]ExerciseLogResponse, 0, len(logs))
	for _, l := range logs {
		logResp = append(logResp, toExerciseLogResponse(l))
	}

	c.JSON(http.StatusOK, gin.H{
		"workout":    toWorkoutResponse(w),
		"exercises":  exResp,
		"logs":       logResp,
	})
}

func (h *Handler) StartWorkout(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	workoutID, ok := parseUUIDParam(c, "workout_id")
	if !ok {
		return
	}

	w, err := h.uc.StartWorkout(c.Request.Context(), user, workoutID, time.Now().UTC())
	if err != nil {
		if err == workoutdomain.ErrWorkoutNotFound || err == workoutdomain.ErrWorkoutForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, toWorkoutResponse(w))
}

func (h *Handler) FinishWorkout(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	workoutID, ok := parseUUIDParam(c, "workout_id")
	if !ok {
		return
	}

	w, err := h.uc.FinishWorkout(c.Request.Context(), user, workoutID, time.Now().UTC())
	if err != nil {
		if err == workoutdomain.ErrWorkoutNotFound || err == workoutdomain.ErrWorkoutForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, toWorkoutResponse(w))
}

func (h *Handler) AddExerciseToWorkout(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	workoutID, ok := parseUUIDParam(c, "workout_id")
	if !ok {
		return
	}

	var req AddExerciseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	exerciseID, err := uuid.Parse(req.ExerciseID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid exercise_id"})
		return
	}

	orderIndex := 0
	if req.OrderIndex != nil {
		orderIndex = *req.OrderIndex
	}

	we, err := h.uc.AddExerciseToWorkout(c.Request.Context(), user, workoutID, exerciseID, req.Sets, req.Reps, req.WeightKg, orderIndex)
	if err != nil {
		if err == workoutdomain.ErrWorkoutNotFound || err == workoutdomain.ErrWorkoutForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		if err == workoutdomain.ErrExerciseNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toWorkoutExerciseResponse(we))
}

func (h *Handler) LogSet(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	workoutID, ok := parseUUIDParam(c, "workout_id")
	if !ok {
		return
	}

	var req LogSetRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	exerciseID, err := uuid.Parse(req.ExerciseID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid exercise_id"})
		return
	}

	el, err := h.uc.LogSet(c.Request.Context(), user, workoutID, exerciseID, req.SetNumber, req.Reps, req.WeightKg, req.RestSeconds)
	if err != nil {
		if err == workoutdomain.ErrWorkoutNotFound || err == workoutdomain.ErrWorkoutForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toExerciseLogResponse(el))
}

func getUser(c *gin.Context) *authdomain.User {
	val, exists := c.Get(string(middleware.UserContextKey))
	if !exists {
		c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return nil
	}
	user, ok := val.(*authdomain.User)
	if !ok {
		c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "forbidden"})
		return nil
	}
	return user
}

func parseUUIDParam(c *gin.Context, key string) (uuid.UUID, bool) {
	raw := c.Param(key)
	id, err := uuid.Parse(raw)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return uuid.Nil, false
	}
	return id, true
}

func formatTimePtr(t *time.Time) string {
	if t == nil {
		return ""
	}
	return t.Format(time.RFC3339)
}

func toExerciseResponse(e *workoutdomain.Exercise) ExerciseResponse {
	return ExerciseResponse{
		ID:          e.ID.String(),
		Name:        e.Name,
		MuscleGroup: e.MuscleGroup,
	}
}

func toWorkoutResponse(w *workoutdomain.Workout) WorkoutResponse {
	var tid, scheduledAt, startedAt, finishedAt *string
	if w.TemplateID != nil {
		s := w.TemplateID.String()
		tid = &s
	}
	if w.ScheduledAt != nil {
		s := formatTimePtr(w.ScheduledAt)
		scheduledAt = &s
	}
	if w.StartedAt != nil {
		s := formatTimePtr(w.StartedAt)
		startedAt = &s
	}
	if w.FinishedAt != nil {
		s := formatTimePtr(w.FinishedAt)
		finishedAt = &s
	}
	return WorkoutResponse{
		ID:          w.ID.String(),
		TemplateID:  tid,
		UserID:      w.UserID.String(),
		ScheduledAt: scheduledAt,
		StartedAt:   startedAt,
		FinishedAt:  finishedAt,
		CreatedAt:   w.CreatedAt.Format(time.RFC3339),
	}
}

func toWorkoutExerciseResponse(we *workoutdomain.WorkoutExercise) WorkoutExerciseResponse {
	return WorkoutExerciseResponse{
		ID:         we.ID.String(),
		ExerciseID: we.ExerciseID.String(),
		Sets:       we.Sets,
		Reps:       we.Reps,
		WeightKg:   we.WeightKg,
		OrderIndex: we.OrderIndex,
	}
}

func toExerciseLogResponse(el *workoutdomain.ExerciseLog) ExerciseLogResponse {
	return ExerciseLogResponse{
		ID:          el.ID.String(),
		ExerciseID:  el.ExerciseID.String(),
		SetNumber:   el.SetNumber,
		Reps:        el.Reps,
		WeightKg:    el.WeightKg,
		RestSeconds: el.RestSeconds,
		LoggedAt:    el.LoggedAt.Format(time.RFC3339),
	}
}
