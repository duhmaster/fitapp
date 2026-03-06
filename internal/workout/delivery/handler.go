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
	ID              string             `json:"id"`
	Name            string             `json:"name"`
	MuscleGroup     *string            `json:"muscle_group,omitempty"`
	Equipment       []string           `json:"equipment,omitempty"`
	Tags            []string           `json:"tags,omitempty"`
	Description     *string            `json:"description,omitempty"`
	Instruction     []string           `json:"instruction,omitempty"`
	MuscleLoads     map[string]float64 `json:"muscle_loads,omitempty"`
	Formula         *string            `json:"formula,omitempty"`
	DifficultyLevel *string            `json:"difficulty_level,omitempty"`
	IsBase          bool               `json:"is_base"`
	IsPopular       bool               `json:"is_popular"`
	IsFree          bool               `json:"is_free"`
}

// ProgramResponse is the JSON response for a program.
type ProgramResponse struct {
	ID          string  `json:"id"`
	Name        string  `json:"name"`
	Description *string `json:"description,omitempty"`
}

// ProgramExerciseResponse is the JSON response for a program exercise (with full exercise).
type ProgramExerciseResponse struct {
	ID         string            `json:"id"`
	ExerciseID string            `json:"exercise_id"`
	OrderIndex int               `json:"order_index"`
	Exercise   *ExerciseResponse  `json:"exercise,omitempty"`
}

// WorkoutResponse is the JSON response for a workout.
type WorkoutResponse struct {
	ID          string   `json:"id"`
	TemplateID  *string  `json:"template_id,omitempty"`
	ProgramID   *string  `json:"program_id,omitempty"`
	UserID      string   `json:"user_id"`
	ScheduledAt *string  `json:"scheduled_at,omitempty"`
	StartedAt   *string  `json:"started_at,omitempty"`
	FinishedAt  *string  `json:"finished_at,omitempty"`
	CreatedAt   string   `json:"created_at"`
	VolumeKg    *float64 `json:"volume_kg,omitempty"`
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
	ProgramID   *string `json:"program_id"`
	ScheduledAt *string `json:"scheduled_at"`
}

type CreateProgramRequest struct {
	Name        string  `json:"name" binding:"required"`
	Description *string `json:"description"`
}

type StartWorkoutRequest struct {
	ProgramID   string  `json:"program_id" binding:"required"`
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

// Workout template DTOs
type TemplateResponse struct {
	ID              string `json:"id"`
	Name            string `json:"name"`
	ExercisesCount  int    `json:"exercises_count,omitempty"`
	CreatedAt       string `json:"created_at,omitempty"`
	UseRestTimer    bool   `json:"use_rest_timer"`
	RestSeconds     int    `json:"rest_seconds"`
}

type TemplateExerciseSetResponse struct {
	ID       string   `json:"id"`
	SetOrder int      `json:"set_order"`
	WeightKg *float64 `json:"weight_kg,omitempty"`
	Reps     *int     `json:"reps,omitempty"`
}

type TemplateExerciseResponse struct {
	ID            string                        `json:"id"`
	ExerciseID    string                        `json:"exercise_id"`
	ExerciseOrder int                           `json:"exercise_order"`
	Exercise      *ExerciseResponse             `json:"exercise,omitempty"`
	Sets          []TemplateExerciseSetResponse `json:"sets,omitempty"`
}

type CreateTemplateRequest struct {
	Name          string `json:"name" binding:"required"`
	UseRestTimer  *bool  `json:"use_rest_timer"`
	RestSeconds   *int   `json:"rest_seconds"`
}

type UpdateTemplateRequest struct {
	Name          string `json:"name" binding:"required"`
	UseRestTimer  *bool  `json:"use_rest_timer"`
	RestSeconds   *int   `json:"rest_seconds"`
}

type AddExerciseToTemplateRequest struct {
	ExerciseID string `json:"exercise_id" binding:"required"`
	Order      *int   `json:"order"`
}

type ReorderTemplateRequest struct {
	ExerciseIDs []string `json:"exercise_ids" binding:"required"`
}

type AddSetToTemplateExerciseRequest struct {
	SetOrder int      `json:"set_order"`
	WeightKg *float64 `json:"weight_kg"`
	Reps     *int     `json:"reps"`
}

func (h *Handler) ListExercises(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	filters := &workoutdomain.ExerciseFilters{}
	if v := c.Query("muscle_group"); v != "" {
		filters.MuscleGroup = &v
	}
	if v := c.Query("difficulty"); v != "" {
		filters.Difficulty = &v
	}
	if tags := c.QueryArray("tags"); len(tags) > 0 {
		filters.Tags = tags
	}

	list, err := h.uc.ListExercises(c.Request.Context(), limit, offset, filters)
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

	var templateID, programID *uuid.UUID
	if req.TemplateID != nil && *req.TemplateID != "" {
		id, err := uuid.Parse(*req.TemplateID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid template_id"})
			return
		}
		templateID = &id
	}
	if req.ProgramID != nil && *req.ProgramID != "" {
		id, err := uuid.Parse(*req.ProgramID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid program_id"})
			return
		}
		programID = &id
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

	w, err := h.uc.CreateWorkout(c.Request.Context(), user, templateID, programID, scheduledAt)
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
		resp := toWorkoutResponse(w)
		logs, _ := h.uc.GetWorkoutLogs(c.Request.Context(), user, w.ID)
		var volume float64
		for _, l := range logs {
			if l.Reps != nil && l.WeightKg != nil && *l.Reps > 0 {
				volume += float64(*l.Reps) * *l.WeightKg
			}
		}
		resp.VolumeKg = &volume
		out = append(out, resp)
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

	var templateName *string
	if w.TemplateID != nil {
		if t, err := h.uc.GetTemplate(c.Request.Context(), user, *w.TemplateID); err == nil {
			templateName = &t.Name
		}
	}
	var volume float64
	for _, l := range logs {
		if l.Reps != nil && l.WeightKg != nil && *l.Reps > 0 {
			volume += float64(*l.Reps) * *l.WeightKg
		}
	}

	exResp := make([]WorkoutExerciseResponse, 0, len(exercises))
	for _, e := range exercises {
		exResp = append(exResp, toWorkoutExerciseResponse(e))
	}
	logResp := make([]ExerciseLogResponse, 0, len(logs))
	for _, l := range logs {
		logResp = append(logResp, toExerciseLogResponse(l))
	}

	out := gin.H{
		"workout":    toWorkoutResponse(w),
		"exercises":  exResp,
		"logs":       logResp,
		"volume_kg":  volume,
	}
	if templateName != nil {
		out["template_name"] = *templateName
	}
	c.JSON(http.StatusOK, out)
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

func (h *Handler) DeleteWorkout(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	workoutID, ok := parseUUIDParam(c, "workout_id")
	if !ok {
		return
	}

	err := h.uc.DeleteWorkout(c.Request.Context(), user, workoutID)
	if err != nil {
		if err == workoutdomain.ErrWorkoutNotFound || err == workoutdomain.ErrWorkoutForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
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

func (h *Handler) ListPrograms(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListPrograms(c.Request.Context(), user, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]ProgramResponse, 0, len(list))
	for _, p := range list {
		out = append(out, toProgramResponse(p))
	}
	c.JSON(http.StatusOK, gin.H{"programs": out})
}

func (h *Handler) CreateProgram(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req CreateProgramRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	desc := ""
	if req.Description != nil {
		desc = *req.Description
	}

	p, err := h.uc.CreateProgram(c.Request.Context(), user, req.Name, desc)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toProgramResponse(p))
}

func (h *Handler) GetProgramExercises(c *gin.Context) {
	programID, ok := parseUUIDParam(c, "id")
	if !ok {
		return
	}

	list, err := h.uc.GetProgramExercises(c.Request.Context(), programID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]ProgramExerciseResponse, 0, len(list))
	for _, pe := range list {
		resp := ProgramExerciseResponse{
			ID:         pe.ID.String(),
			ExerciseID: pe.ExerciseID.String(),
			OrderIndex: pe.OrderIndex,
		}
		if pe.Exercise != nil {
			ex := toExerciseResponse(pe.Exercise)
			resp.Exercise = &ex
		}
		out = append(out, resp)
	}
	c.JSON(http.StatusOK, gin.H{"exercises": out})
}

func (h *Handler) StartWorkoutFromProgram(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req StartWorkoutRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	programID, err := uuid.Parse(req.ProgramID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid program_id"})
		return
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

	w, err := h.uc.StartWorkoutFromProgram(c.Request.Context(), user, programID, scheduledAt)
	if err != nil {
		if err == workoutdomain.ErrProgramNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toWorkoutResponse(w))
}

// --- Workout templates ---

func (h *Handler) ListTemplates(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListTemplates(c.Request.Context(), user, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]TemplateResponse, 0, len(list))
	for _, t := range list {
		count, _ := h.uc.CountTemplateExercises(c.Request.Context(), user, t.ID)
		out = append(out, TemplateResponse{
			ID:             t.ID.String(),
			Name:           t.Name,
			ExercisesCount: count,
			CreatedAt:      t.CreatedAt.Format(time.RFC3339),
		})
	}
	c.JSON(http.StatusOK, gin.H{"templates": out})
}

func (h *Handler) GetTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateID, ok := parseUUIDParam(c, "template_id")
	if !ok {
		return
	}

	t, exercises, err := h.uc.GetTemplateWithExercises(c.Request.Context(), user, templateID)
	if err != nil {
		if err == workoutdomain.ErrTemplateNotFound || err == workoutdomain.ErrTemplateForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	exResp := make([]TemplateExerciseResponse, 0, len(exercises))
	for _, te := range exercises {
		exResp = append(exResp, toTemplateExerciseResponse(te))
	}
	c.JSON(http.StatusOK, gin.H{
		"template":   toTemplateResponse(t),
		"exercises":  exResp,
	})
}

func (h *Handler) CreateTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	var req CreateTemplateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	useRestTimer := false
	if req.UseRestTimer != nil {
		useRestTimer = *req.UseRestTimer
	}
	restSeconds := 60
	if req.RestSeconds != nil {
		restSeconds = *req.RestSeconds
	}
	if restSeconds < 1 {
		restSeconds = 1
	}
	if restSeconds > 600 {
		restSeconds = 600
	}
	t, err := h.uc.CreateTemplate(c.Request.Context(), user, req.Name, useRestTimer, restSeconds)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toTemplateResponseSimple(t))
}

func (h *Handler) UpdateTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateID, ok := parseUUIDParam(c, "template_id")
	if !ok {
		return
	}
	var req UpdateTemplateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	useRestTimer := false
	if req.UseRestTimer != nil {
		useRestTimer = *req.UseRestTimer
	}
	restSeconds := 60
	if req.RestSeconds != nil {
		restSeconds = *req.RestSeconds
	}
	if restSeconds < 1 {
		restSeconds = 1
	}
	if restSeconds > 600 {
		restSeconds = 600
	}
	t, err := h.uc.UpdateTemplate(c.Request.Context(), user, templateID, req.Name, useRestTimer, restSeconds)
	if err != nil {
		if err == workoutdomain.ErrTemplateNotFound || err == workoutdomain.ErrTemplateForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, toTemplateResponseSimple(t))
}

func (h *Handler) DeleteTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateID, ok := parseUUIDParam(c, "template_id")
	if !ok {
		return
	}
	err := h.uc.DeleteTemplate(c.Request.Context(), user, templateID)
	if err != nil {
		if err == workoutdomain.ErrTemplateNotFound || err == workoutdomain.ErrTemplateForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) AddExerciseToTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateID, ok := parseUUIDParam(c, "template_id")
	if !ok {
		return
	}
	var req AddExerciseToTemplateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	exerciseID, err := uuid.Parse(req.ExerciseID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid exercise_id"})
		return
	}
	order := 0
	if req.Order != nil {
		order = *req.Order
	}
	te, err := h.uc.AddExerciseToTemplate(c.Request.Context(), user, templateID, exerciseID, order)
	if err != nil {
		if err == workoutdomain.ErrTemplateNotFound || err == workoutdomain.ErrTemplateForbidden {
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
	c.JSON(http.StatusCreated, toTemplateExerciseResponse(te))
}

func (h *Handler) RemoveExerciseFromTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateExerciseID, ok := parseUUIDParam(c, "template_exercise_id")
	if !ok {
		return
	}
	err := h.uc.RemoveExerciseFromTemplate(c.Request.Context(), user, templateExerciseID)
	if err != nil {
		if err == workoutdomain.ErrTemplateExerciseNotFound || err == workoutdomain.ErrTemplateNotFound || err == workoutdomain.ErrTemplateForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) ReorderTemplateExercises(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateID, ok := parseUUIDParam(c, "template_id")
	if !ok {
		return
	}
	var req ReorderTemplateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	ids := make([]uuid.UUID, 0, len(req.ExerciseIDs))
	for _, s := range req.ExerciseIDs {
		id, err := uuid.Parse(s)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid exercise_id in exercise_ids"})
			return
		}
		ids = append(ids, id)
	}
	err := h.uc.ReorderTemplateExercises(c.Request.Context(), user, templateID, ids)
	if err != nil {
		if err == workoutdomain.ErrTemplateNotFound || err == workoutdomain.ErrTemplateForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) AddSetToTemplateExercise(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateExerciseID, ok := parseUUIDParam(c, "template_exercise_id")
	if !ok {
		return
	}
	var req AddSetToTemplateExerciseRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	s, err := h.uc.AddSetToTemplateExercise(c.Request.Context(), user, templateExerciseID, req.SetOrder, req.WeightKg, req.Reps)
	if err != nil {
		if err == workoutdomain.ErrTemplateExerciseNotFound || err == workoutdomain.ErrTemplateNotFound || err == workoutdomain.ErrTemplateForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toTemplateSetResponse(s))
}

func (h *Handler) DeleteTemplateSet(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateExerciseID, ok := parseUUIDParam(c, "template_exercise_id")
	if !ok {
		return
	}
	setID, ok := parseUUIDParam(c, "set_id")
	if !ok {
		return
	}
	err := h.uc.DeleteTemplateSet(c.Request.Context(), user, templateExerciseID, setID)
	if err != nil {
		if err == workoutdomain.ErrTemplateNotFound || err == workoutdomain.ErrTemplateForbidden || err == workoutdomain.ErrTemplateExerciseNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) StartWorkoutFromTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateID, ok := parseUUIDParam(c, "template_id")
	if !ok {
		return
	}
	w, err := h.uc.StartWorkoutFromTemplate(c.Request.Context(), user, templateID, nil)
	if err != nil {
		if err == workoutdomain.ErrTemplateNotFound || err == workoutdomain.ErrTemplateForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"workout": toWorkoutResponse(w)})
}

// ListProgressExerciseIDs returns exercise IDs that appear in user's workout logs.
func (h *Handler) ListProgressExerciseIDs(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	ids, err := h.uc.ListUserExerciseIDsForProgress(c.Request.Context(), user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]string, 0, len(ids))
	for _, id := range ids {
		out = append(out, id.String())
	}
	c.JSON(http.StatusOK, gin.H{"exercise_ids": out})
}

// ExerciseVolumeHistoryResponse is one workout's volume for an exercise.
type ExerciseVolumeHistoryResponse struct {
	WorkoutID   string  `json:"workout_id"`
	WorkoutDate string  `json:"workout_date"`
	VolumeKg    float64 `json:"volume_kg"`
}

// ListExerciseVolumeHistory returns per-workout volume for an exercise.
func (h *Handler) ListExerciseVolumeHistory(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	exerciseID, ok := parseUUIDParam(c, "exercise_id")
	if !ok {
		return
	}
	list, err := h.uc.ListExerciseVolumeHistoryForProgress(c.Request.Context(), user, exerciseID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]ExerciseVolumeHistoryResponse, 0, len(list))
	for _, e := range list {
		out = append(out, ExerciseVolumeHistoryResponse{
			WorkoutID:   e.WorkoutID.String(),
			WorkoutDate: e.WorkoutDate.Format(time.RFC3339),
			VolumeKg:    e.VolumeKg,
		})
	}
	c.JSON(http.StatusOK, gin.H{"history": out})
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
		ID:              e.ID.String(),
		Name:            e.Name,
		MuscleGroup:     e.MuscleGroup,
		Equipment:       e.Equipment,
		Tags:            e.Tags,
		Description:     e.Description,
		Instruction:     e.Instruction,
		MuscleLoads:     e.MuscleLoads,
		Formula:         e.Formula,
		DifficultyLevel: e.DifficultyLevel,
		IsBase:          e.IsBase,
		IsPopular:       e.IsPopular,
		IsFree:          e.IsFree,
	}
}

func toProgramResponse(p *workoutdomain.Program) ProgramResponse {
	return ProgramResponse{
		ID:          p.ID.String(),
		Name:        p.Name,
		Description: p.Description,
	}
}

func toWorkoutResponse(w *workoutdomain.Workout) WorkoutResponse {
	var tid, pid, scheduledAt, startedAt, finishedAt *string
	if w.TemplateID != nil {
		s := w.TemplateID.String()
		tid = &s
	}
	if w.ProgramID != nil {
		s := w.ProgramID.String()
		pid = &s
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
		ProgramID:   pid,
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

func toTemplateResponse(t *workoutdomain.WorkoutTemplate) TemplateResponse {
	return TemplateResponse{
		ID:           t.ID.String(),
		Name:         t.Name,
		CreatedAt:    t.CreatedAt.Format(time.RFC3339),
		UseRestTimer: t.UseRestTimer,
		RestSeconds:  t.RestSeconds,
	}
}

func toTemplateResponseSimple(t *workoutdomain.WorkoutTemplate) TemplateResponse {
	return TemplateResponse{
		ID:           t.ID.String(),
		Name:         t.Name,
		CreatedAt:    t.CreatedAt.Format(time.RFC3339),
		UseRestTimer: t.UseRestTimer,
		RestSeconds:  t.RestSeconds,
	}
}

func toTemplateExerciseResponse(te *workoutdomain.WorkoutTemplateExercise) TemplateExerciseResponse {
	resp := TemplateExerciseResponse{
		ID:            te.ID.String(),
		ExerciseID:    te.ExerciseID.String(),
		ExerciseOrder: te.ExerciseOrder,
	}
	if te.Exercise != nil {
		ex := toExerciseResponse(te.Exercise)
		resp.Exercise = &ex
	}
	if len(te.Sets) > 0 {
		resp.Sets = make([]TemplateExerciseSetResponse, 0, len(te.Sets))
		for _, s := range te.Sets {
			resp.Sets = append(resp.Sets, TemplateExerciseSetResponse{
				ID:       s.ID.String(),
				SetOrder: s.SetOrder,
				WeightKg: s.WeightKg,
				Reps:     s.Reps,
			})
		}
	}
	return resp
}

func toTemplateSetResponse(s *workoutdomain.TemplateExerciseSet) TemplateExerciseSetResponse {
	return TemplateExerciseSetResponse{
		ID:       s.ID.String(),
		SetOrder: s.SetOrder,
		WeightKg: s.WeightKg,
		Reps:     s.Reps,
	}
}
