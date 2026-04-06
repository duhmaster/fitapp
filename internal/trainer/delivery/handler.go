package delivery

import (
	"context"
	"io"
	"net/http"
	"strconv"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	trainerdomain "github.com/fitflow/fitflow/internal/trainer/domain"
	"github.com/fitflow/fitflow/internal/trainer/usecase"
	workoutdomain "github.com/fitflow/fitflow/internal/workout/domain"
	workoutusecase "github.com/fitflow/fitflow/internal/workout/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// ClientProfileGym is a minimal gym info for client profile response.
type ClientProfileGym = PublicProfileGym

// ClientProfileMeasurement is a single body measurement in the client profile response.
type ClientProfileMeasurement struct {
	ID         string   `json:"id"`
	RecordedAt string   `json:"recorded_at"`
	WeightKg   float64  `json:"weight_kg"`
	BodyFatPct *float64 `json:"body_fat_pct,omitempty"`
	HeightCm   *float64 `json:"height_cm,omitempty"`
}

type Handler struct {
	uc              *usecase.TrainerUseCase
	profileResolver func(context.Context, uuid.UUID) (displayName, city, avatarURL string)
	photoStore      interface {
		Save(ctx context.Context, path string, r io.Reader, contentType string) (string, error)
	}
	getWorkoutCount func(context.Context, uuid.UUID) (int, error)
	getGymsForUser  func(context.Context, uuid.UUID) ([]PublicProfileGym, error)

	getLatestMetric      func(context.Context, uuid.UUID) (heightCm, weightKg *float64, err error)
	getLatestBodyFat     func(context.Context, uuid.UUID) (*float64, error)
	getBodyMeasurements  func(context.Context, uuid.UUID, int) ([]ClientProfileMeasurement, error)
	getClientWorkouts    func(context.Context, uuid.UUID, int, int) ([]map[string]interface{}, error)

	getClientExerciseIDs          func(context.Context, uuid.UUID) ([]string, error)
	getClientExerciseVolumeHistory func(context.Context, uuid.UUID, uuid.UUID) ([]map[string]interface{}, error)

	workoutUC *workoutusecase.WorkoutUseCase
}

// PublicProfileGym is a minimal gym info for public trainer profile (avoids importing gym domain).
type PublicProfileGym struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	City string `json:"city,omitempty"`
}

func NewHandler(uc *usecase.TrainerUseCase) *Handler {
	return &Handler{uc: uc}
}

func (h *Handler) SetProfileResolver(fn func(context.Context, uuid.UUID) (displayName, city, avatarURL string)) {
	h.profileResolver = fn
}

func (h *Handler) SetPublicProfileDeps(
	getWorkoutCount func(context.Context, uuid.UUID) (int, error),
	getGymsForUser func(context.Context, uuid.UUID) ([]PublicProfileGym, error),
) {
	h.getWorkoutCount = getWorkoutCount
	h.getGymsForUser = getGymsForUser
}

func (h *Handler) SetPhotoStore(store interface {
	Save(ctx context.Context, path string, r io.Reader, contentType string) (string, error)
}) {
	h.photoStore = store
}

func (h *Handler) SetClientProfileDeps(
	getLatestMetric func(context.Context, uuid.UUID) (*float64, *float64, error),
	getLatestBodyFat func(context.Context, uuid.UUID) (*float64, error),
	getBodyMeasurements func(context.Context, uuid.UUID, int) ([]ClientProfileMeasurement, error),
	getGymsForUser func(context.Context, uuid.UUID) ([]PublicProfileGym, error),
	getClientWorkouts func(context.Context, uuid.UUID, int, int) ([]map[string]interface{}, error),
) {
	h.getLatestMetric = getLatestMetric
	h.getLatestBodyFat = getLatestBodyFat
	h.getBodyMeasurements = getBodyMeasurements
	if getGymsForUser != nil {
		h.getGymsForUser = getGymsForUser
	}
	h.getClientWorkouts = getClientWorkouts
}

func (h *Handler) SetClientProgressDeps(
	getExerciseIDs func(context.Context, uuid.UUID) ([]string, error),
	getExerciseVolumeHistory func(context.Context, uuid.UUID, uuid.UUID) ([]map[string]interface{}, error),
) {
	h.getClientExerciseIDs = getExerciseIDs
	h.getClientExerciseVolumeHistory = getExerciseVolumeHistory
}

func (h *Handler) SetWorkoutUseCase(uc *workoutusecase.WorkoutUseCase) {
	h.workoutUC = uc
}

type TrainerClientResponse struct {
	ID        string `json:"id"`
	TrainerID string `json:"trainer_id"`
	ClientID  string `json:"client_id"`
	Status    string `json:"status"`
	CreatedAt string `json:"created_at"`
}

type TrainingProgramResponse struct {
	ID         string  `json:"id"`
	TrainerID  string  `json:"trainer_id"`
	ClientID   string  `json:"client_id"`
	Name       string  `json:"name"`
	AssignedAt *string `json:"assigned_at,omitempty"`
	CreatedAt  string  `json:"created_at"`
}

type TrainerCommentResponse struct {
	ID        string `json:"id"`
	TrainerID string `json:"trainer_id"`
	ClientID  string `json:"client_id"`
	Content   string `json:"content"`
	CreatedAt string `json:"created_at"`
}

type AddClientRequest struct {
	ClientID string `json:"client_id" binding:"required"`
	Status   string `json:"status"`
}

type SetClientStatusRequest struct {
	Status string `json:"status" binding:"required"`
}

type CreateProgramRequest struct {
	ClientID   string  `json:"client_id" binding:"required"`
	Name       string  `json:"name" binding:"required"`
	AssignedAt *string `json:"assigned_at"`
}

type UpdateProgramRequest struct {
	Name       string  `json:"name"`
	AssignedAt *string `json:"assigned_at"`
}

type AddCommentRequest struct {
	Content string `json:"content" binding:"required"`
}

type TrainerProfileResponse struct {
	AboutMe   string `json:"about_me"`
	Contacts  string `json:"contacts"`
	CreatedAt string `json:"created_at"`
	UpdatedAt string `json:"updated_at"`
}

type TrainerPhotoResponse struct {
	ID        string `json:"id"`
	URL       string `json:"url"`
	Position  int    `json:"position"`
	CreatedAt string `json:"created_at"`
}

type UpdateTrainerProfileRequest struct {
	AboutMe  string `json:"about_me"`
	Contacts string `json:"contacts"`
}

type AddMyTrainerRequest struct {
	TrainerID string `json:"trainer_id" binding:"required"`
}

type TrainerSearchItemResponse struct {
	ID          string `json:"id"`
	DisplayName string `json:"display_name"`
	City        string `json:"city"`
}

func (h *Handler) GetMyTrainerProfile(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	p, err := h.uc.GetMyTrainerProfile(c.Request.Context(), user)
	if err != nil {
		if err == trainerdomain.ErrTrainerProfileNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "trainer profile not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, TrainerProfileResponse{
		AboutMe:   p.AboutMe,
		Contacts:  p.Contacts,
		CreatedAt: p.CreatedAt.Format(time.RFC3339),
		UpdatedAt: p.UpdatedAt.Format(time.RFC3339),
	})
}

func (h *Handler) UpdateMyTrainerProfile(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	var req UpdateTrainerProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	p, err := h.uc.UpdateMyTrainerProfile(c.Request.Context(), user, req.AboutMe, req.Contacts)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, TrainerProfileResponse{
		AboutMe:   p.AboutMe,
		Contacts:  p.Contacts,
		CreatedAt: p.CreatedAt.Format(time.RFC3339),
		UpdatedAt: p.UpdatedAt.Format(time.RFC3339),
	})
}

func (h *Handler) ListMyTrainerPhotos(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	list, err := h.uc.ListMyTrainerPhotos(c.Request.Context(), user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]TrainerPhotoResponse, 0, len(list))
	for _, ph := range list {
		out = append(out, TrainerPhotoResponse{
			ID:        ph.ID.String(),
			URL:       ph.Path,
			Position:  ph.Position,
			CreatedAt: ph.CreatedAt.Format(time.RFC3339),
		})
	}
	c.JSON(http.StatusOK, gin.H{"photos": out})
}

func (h *Handler) UploadTrainerPhoto(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	if h.photoStore == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "photo upload not configured"})
		return
	}
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "file required"})
		return
	}
	if file.Size > 5*1024*1024 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "file too large (max 5MB)"})
		return
	}
	ct := file.Header.Get("Content-Type")
	if ct != "image/jpeg" && ct != "image/png" && ct != "image/webp" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid file type (jpeg, png, webp only)"})
		return
	}
	f, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to read file"})
		return
	}
	defer f.Close()
	path := "trainer_photos/" + user.ID.String() + "/" + uuid.New().String()
	switch ct {
	case "image/jpeg", "image/png":
		path += ".jpg"
	default:
		path += ".webp"
	}
	url, err := h.photoStore.Save(c.Request.Context(), path, f, ct)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to save photo"})
		return
	}
	position := 0
	if p := c.PostForm("position"); p != "" {
		if n, e := strconv.Atoi(p); e == nil {
			position = n
		}
	}
	ph, err := h.uc.AddTrainerPhoto(c.Request.Context(), user, url, position)
	if err != nil {
		if err == trainerdomain.ErrTrainerPhotoLimitReached {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, TrainerPhotoResponse{
		ID:        ph.ID.String(),
		URL:       ph.Path,
		Position:  ph.Position,
		CreatedAt: ph.CreatedAt.Format(time.RFC3339),
	})
}

func (h *Handler) DeleteTrainerPhoto(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	photoID, ok := parseUUIDParam(c, "photo_id")
	if !ok {
		return
	}
	if err := h.uc.DeleteTrainerPhoto(c.Request.Context(), user, photoID); err != nil {
		if err == trainerdomain.ErrTrainerPhotoNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) SearchTrainers(c *gin.Context) {
	q := c.Query("q")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	ids, err := h.uc.SearchTrainerUserIDs(c.Request.Context(), q, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]TrainerSearchItemResponse, 0, len(ids))
	for _, id := range ids {
		displayName, city := "", ""
		if h.profileResolver != nil {
			displayName, city, _ = h.profileResolver(c.Request.Context(), id)
		}
		out = append(out, TrainerSearchItemResponse{
			ID:          id.String(),
			DisplayName: displayName,
			City:        city,
		})
	}
	c.JSON(http.StatusOK, gin.H{"trainers": out})
}

func (h *Handler) AddMyTrainer(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	var req AddMyTrainerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	trainerID, err := uuid.Parse(req.TrainerID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid trainer_id"})
		return
	}
	tc, err := h.uc.AddMyTrainer(c.Request.Context(), user, trainerID)
	if err != nil {
		if err == trainerdomain.ErrTrainerProfileNotFound {
			c.JSON(http.StatusBadRequest, gin.H{"error": "trainer not found"})
			return
		}
		if err == trainerdomain.ErrAlreadyClient {
			c.JSON(http.StatusConflict, gin.H{"error": "already added"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toTrainerClientResponse(tc))
}

func (h *Handler) RemoveMyTrainer(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	trainerID, ok := parseUUIDParam(c, "trainer_id")
	if !ok {
		return
	}
	if err := h.uc.RemoveMyTrainer(c.Request.Context(), user, trainerID); err != nil {
		if err == trainerdomain.ErrTrainerClientNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "not linked"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) AddClient(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}

	var req AddClientRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	clientID, err := uuid.Parse(req.ClientID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid client_id"})
		return
	}

	status := req.Status
	if status == "" {
		status = "active"
	}
	if status != "active" && status != "inactive" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "status must be active or inactive"})
		return
	}

	tc, err := h.uc.AddClient(c.Request.Context(), trainer, clientID, status)
	if err != nil {
		if err == trainerdomain.ErrAlreadyClient {
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toTrainerClientResponse(tc))
}

func (h *Handler) SetClientStatus(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}

	clientID, ok := parseUUIDParam(c, "client_id")
	if !ok {
		return
	}

	var req SetClientStatusRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.Status != "active" && req.Status != "inactive" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "status must be active or inactive"})
		return
	}

	tc, err := h.uc.SetClientStatus(c.Request.Context(), trainer, clientID, req.Status)
	if err != nil {
		if err == trainerdomain.ErrTrainerClientNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, toTrainerClientResponse(tc))
}

func (h *Handler) RemoveClient(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}
	clientID, ok := parseUUIDParam(c, "client_id")
	if !ok {
		return
	}
	if err := h.uc.RemoveClient(c.Request.Context(), trainer, clientID); err != nil {
		if err == trainerdomain.ErrTrainerClientNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) GetClientProfile(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}
	clientID, ok := parseUUIDParam(c, "client_id")
	if !ok {
		return
	}
	ctx := c.Request.Context()

	ok2, err := h.uc.IsClientOfTrainer(ctx, trainer.ID, clientID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if !ok2 {
		c.JSON(http.StatusNotFound, gin.H{"error": "client not found"})
		return
	}

	out := map[string]interface{}{
		"client_id": clientID.String(),
	}

	if h.profileResolver != nil {
		dn, city, avatarURL := h.profileResolver(ctx, clientID)
		out["display_name"] = dn
		out["city"] = city
		out["avatar_url"] = avatarURL
	}

	if h.getLatestMetric != nil {
		heightCm, weightKg, _ := h.getLatestMetric(ctx, clientID)
		if heightCm != nil {
			out["height_cm"] = *heightCm
		}
		if weightKg != nil {
			out["weight_kg"] = *weightKg
		}
	}

	if h.getLatestBodyFat != nil {
		bodyFat, _ := h.getLatestBodyFat(ctx, clientID)
		if bodyFat != nil {
			out["body_fat_pct"] = *bodyFat
		}
	}

	if h.getBodyMeasurements != nil {
		measurements, _ := h.getBodyMeasurements(ctx, clientID, 100)
		out["measurements"] = measurements
	}

	if h.getGymsForUser != nil {
		gyms, _ := h.getGymsForUser(ctx, clientID)
		out["gyms"] = gyms
	}

	if h.getClientWorkouts != nil {
		workouts, _ := h.getClientWorkouts(ctx, clientID, 200, 0)
		out["workouts"] = workouts
	}

	c.JSON(http.StatusOK, out)
}

func (h *Handler) GetClientProgressExerciseIDs(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}
	clientID, ok := parseUUIDParam(c, "client_id")
	if !ok {
		return
	}
	ok2, err := h.uc.IsClientOfTrainer(c.Request.Context(), trainer.ID, clientID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if !ok2 {
		c.JSON(http.StatusNotFound, gin.H{"error": "client not found"})
		return
	}
	if h.getClientExerciseIDs == nil {
		c.JSON(http.StatusOK, gin.H{"exercise_ids": []string{}})
		return
	}
	ids, err := h.getClientExerciseIDs(c.Request.Context(), clientID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"exercise_ids": ids})
}

func (h *Handler) GetClientExerciseVolumeHistory(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}
	clientID, ok := parseUUIDParam(c, "client_id")
	if !ok {
		return
	}
	exerciseID, ok := parseUUIDParam(c, "exercise_id")
	if !ok {
		return
	}
	ok2, err := h.uc.IsClientOfTrainer(c.Request.Context(), trainer.ID, clientID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if !ok2 {
		c.JSON(http.StatusNotFound, gin.H{"error": "client not found"})
		return
	}
	if h.getClientExerciseVolumeHistory == nil {
		c.JSON(http.StatusOK, gin.H{"history": []interface{}{}})
		return
	}
	history, err := h.getClientExerciseVolumeHistory(c.Request.Context(), clientID, exerciseID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"history": history})
}

type createClientTemplateRequest struct {
	Name         string `json:"name" binding:"required"`
	UseRestTimer *bool  `json:"use_rest_timer"`
	RestSeconds  *int   `json:"rest_seconds"`
}

type createClientWorkoutRequest struct {
	TemplateID  *string `json:"template_id"`
	ScheduledAt *string `json:"scheduled_at"`
	GymID       *string `json:"gym_id"`
}

func (h *Handler) CreateClientTemplate(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}
	clientID, ok := parseUUIDParam(c, "client_id")
	if !ok {
		return
	}
	if h.workoutUC == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "workout service unavailable"})
		return
	}
	var req createClientTemplateRequest
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
	t, err := h.workoutUC.CreateTemplateForClient(c.Request.Context(), trainer, clientID, req.Name, useRestTimer, restSeconds)
	if err != nil {
		if err == workoutdomain.ErrTemplateForbidden {
			c.JSON(http.StatusForbidden, gin.H{"error": "not your client"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"id":            t.ID.String(),
		"name":          t.Name,
		"created_at":    t.CreatedAt.Format(time.RFC3339),
		"use_rest_timer": t.UseRestTimer,
		"rest_seconds":  t.RestSeconds,
	})
}

func (h *Handler) ListClientTemplates(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}
	clientID, ok := parseUUIDParam(c, "client_id")
	if !ok {
		return
	}
	if h.workoutUC == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "workout service unavailable"})
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	list, err := h.workoutUC.ListTemplatesForClient(c.Request.Context(), trainer, clientID, limit, offset)
	if err != nil {
		if err == workoutdomain.ErrTemplateForbidden {
			c.JSON(http.StatusForbidden, gin.H{"error": "not your client"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]map[string]interface{}, 0, len(list))
	for _, t := range list {
		count, _ := h.workoutUC.CountTemplateExercises(c.Request.Context(), trainer, t.ID)
		out = append(out, map[string]interface{}{
			"id":              t.ID.String(),
			"name":            t.Name,
			"exercises_count": count,
			"created_at":      t.CreatedAt.Format(time.RFC3339),
		})
	}
	c.JSON(http.StatusOK, gin.H{"templates": out})
}

func (h *Handler) CreateClientWorkout(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}
	clientID, ok := parseUUIDParam(c, "client_id")
	if !ok {
		return
	}
	if h.workoutUC == nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "workout service unavailable"})
		return
	}
	var req createClientWorkoutRequest
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
	var gymID *uuid.UUID
	if req.GymID != nil && *req.GymID != "" {
		id, err := uuid.Parse(*req.GymID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid gym_id"})
			return
		}
		gymID = &id
	}

	w, err := h.workoutUC.CreateWorkoutForClient(c.Request.Context(), trainer, clientID, templateID, scheduledAt, gymID)
	if err != nil {
		if err.Error() == "client not found or access denied" {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	// Если указан зал, убеждаемся, что он привязан к подопечному.
	if gymID != nil {
		_ = h.uc.AddGymToClientIfMissing(c.Request.Context(), trainer, clientID, *gymID)
	}
	c.JSON(http.StatusCreated, toClientWorkoutResponse(w))
}

func toClientWorkoutResponse(w *workoutdomain.Workout) gin.H {
	resp := gin.H{
		"id":         w.ID.String(),
		"user_id":    w.UserID.String(),
		"scheduled_at": nil,
		"started_at":  nil,
		"finished_at": nil,
		"created_at":  w.CreatedAt.Format(time.RFC3339),
	}
	if w.TemplateID != nil {
		resp["template_id"] = w.TemplateID.String()
	} else {
		resp["template_id"] = nil
	}
	if w.ProgramID != nil {
		resp["program_id"] = w.ProgramID.String()
	} else {
		resp["program_id"] = nil
	}
	if w.TrainerID != nil {
		resp["trainer_id"] = w.TrainerID.String()
	} else {
		resp["trainer_id"] = nil
	}
	if w.ScheduledAt != nil {
		resp["scheduled_at"] = w.ScheduledAt.Format(time.RFC3339)
	}
	if w.StartedAt != nil {
		resp["started_at"] = w.StartedAt.Format(time.RFC3339)
	}
	if w.FinishedAt != nil {
		resp["finished_at"] = w.FinishedAt.Format(time.RFC3339)
	}
	return resp
}

func (h *Handler) ListMyClients(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}

	status := c.Query("status")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListMyClients(c.Request.Context(), trainer, status, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]map[string]interface{}, 0, len(list))
	for _, tc := range list {
		m := map[string]interface{}{
			"id":         tc.ID.String(),
			"trainer_id": tc.TrainerID.String(),
			"client_id":  tc.ClientID.String(),
			"status":     tc.Status,
			"created_at": tc.CreatedAt.Format(time.RFC3339),
		}
		if h.profileResolver != nil {
			dn, city, _ := h.profileResolver(c.Request.Context(), tc.ClientID)
			m["display_name"] = dn
			m["city"] = city
		}
		out = append(out, m)
	}
	c.JSON(http.StatusOK, gin.H{"clients": out})
}

func (h *Handler) ListMyTrainers(c *gin.Context) {
	client := getUser(c)
	if client == nil {
		return
	}

	status := c.Query("status")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListMyTrainers(c.Request.Context(), client, status, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]map[string]interface{}, 0, len(list))
	for _, tc := range list {
		m := map[string]interface{}{
			"trainer_id": tc.TrainerID.String(),
			"client_id":  tc.ClientID.String(),
			"status":     tc.Status,
			"created_at": tc.CreatedAt.Format(time.RFC3339),
		}
		if h.profileResolver != nil {
			dn, city, _ := h.profileResolver(c.Request.Context(), tc.TrainerID)
			m["display_name"] = dn
			m["city"] = city
		}
		out = append(out, m)
	}
	c.JSON(http.StatusOK, gin.H{"trainers": out})
}

// TrainerPublicProfileResponse is the response for GET /trainers/:user_id (no auth).
type TrainerPublicProfileResponse struct {
	UserID        string                   `json:"user_id"`
	DisplayName   string                   `json:"display_name"`
	City          string                   `json:"city"`
	AvatarURL     string                   `json:"avatar_url"`
	AboutMe       string                   `json:"about_me"`
	Contacts      string                   `json:"contacts"`
	ProfileLink   string                   `json:"profile_link"`
	Photos        []TrainerPhotoResponse   `json:"photos"`
	TraineesCount int                      `json:"trainees_count"`
	WorkoutsCount int                      `json:"workouts_count"`
	Rating        *float64                 `json:"rating,omitempty"`
	Gyms          []PublicProfileGym       `json:"gyms"`
}

func (h *Handler) GetTrainerPublic(c *gin.Context) {
	userID, ok := parseUUIDParam(c, "user_id")
	if !ok {
		return
	}
	ctx := c.Request.Context()

	profile, err := h.uc.GetTrainerProfileByUserID(ctx, userID)
	if err != nil {
		if err == trainerdomain.ErrTrainerProfileNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "trainer not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	displayName, city, avatarURL := "", "", ""
	if h.profileResolver != nil {
		displayName, city, avatarURL = h.profileResolver(ctx, userID)
	}

	photos, _ := h.uc.ListTrainerPhotosByUserID(ctx, userID)
	photoResp := make([]TrainerPhotoResponse, 0, len(photos))
	for _, ph := range photos {
		photoResp = append(photoResp, TrainerPhotoResponse{
			ID:        ph.ID.String(),
			URL:       ph.Path,
			Position:  ph.Position,
			CreatedAt: ph.CreatedAt.Format(time.RFC3339),
		})
	}

	traineesCount, _ := h.uc.CountTrainees(ctx, userID)
	workoutsCount := 0
	if h.getWorkoutCount != nil {
		workoutsCount, _ = h.getWorkoutCount(ctx, userID)
	}
	var gyms []PublicProfileGym
	if h.getGymsForUser != nil {
		gyms, _ = h.getGymsForUser(ctx, userID)
	}
	if gyms == nil {
		gyms = []PublicProfileGym{}
	}

	scheme := "https"
	if c.GetHeader("X-Forwarded-Proto") == "http" || c.Request.URL.Scheme == "http" {
		scheme = "http"
	}
	profileLink := scheme + "://" + c.Request.Host + "/t/" + userID.String()

	resp := TrainerPublicProfileResponse{
		UserID:        userID.String(),
		DisplayName:   displayName,
		City:          city,
		AvatarURL:     avatarURL,
		AboutMe:       profile.AboutMe,
		Contacts:      profile.Contacts,
		ProfileLink:   profileLink,
		Photos:        photoResp,
		TraineesCount: traineesCount,
		WorkoutsCount: workoutsCount,
		Rating:        nil,
		Gyms:          gyms,
	}
	c.JSON(http.StatusOK, resp)
}

func (h *Handler) CreateProgram(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}

	var req CreateProgramRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	clientID, err := uuid.Parse(req.ClientID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid client_id"})
		return
	}

	var assignedAt *time.Time
	if req.AssignedAt != nil && *req.AssignedAt != "" {
		t, err := time.Parse(time.RFC3339, *req.AssignedAt)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid assigned_at"})
			return
		}
		assignedAt = &t
	}

	tp, err := h.uc.CreateProgram(c.Request.Context(), trainer, clientID, req.Name, assignedAt)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toProgramResponse(tp))
}

func (h *Handler) GetProgram(c *gin.Context) {
	programID, ok := parseUUIDParam(c, "id")
	if !ok {
		return
	}

	tp, err := h.uc.GetProgram(c.Request.Context(), programID)
	if err != nil {
		if err == trainerdomain.ErrTrainingProgramNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, toProgramResponse(tp))
}

func (h *Handler) UpdateProgram(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}

	programID, ok := parseUUIDParam(c, "program_id")
	if !ok {
		return
	}

	var req UpdateProgramRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	var assignedAt *time.Time
	if req.AssignedAt != nil && *req.AssignedAt != "" {
		t, err := time.Parse(time.RFC3339, *req.AssignedAt)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid assigned_at"})
			return
		}
		assignedAt = &t
	}

	tp, err := h.uc.UpdateProgram(c.Request.Context(), trainer, programID, req.Name, assignedAt)
	if err != nil {
		if err == trainerdomain.ErrTrainingProgramNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, toProgramResponse(tp))
}

func (h *Handler) DeleteProgram(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}

	programID, ok := parseUUIDParam(c, "program_id")
	if !ok {
		return
	}

	err := h.uc.DeleteProgram(c.Request.Context(), trainer, programID)
	if err != nil {
		if err == trainerdomain.ErrTrainingProgramNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) ListMyPrograms(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}

	clientIDParam := c.Query("client_id")
	var clientID *uuid.UUID
	if clientIDParam != "" {
		id, err := uuid.Parse(clientIDParam)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid client_id"})
			return
		}
		clientID = &id
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListProgramsAsTrainer(c.Request.Context(), trainer, clientID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]TrainingProgramResponse, 0, len(list))
	for _, tp := range list {
		out = append(out, toProgramResponse(tp))
	}
	c.JSON(http.StatusOK, gin.H{"programs": out})
}

func (h *Handler) ListClientPrograms(c *gin.Context) {
	client := getUser(c)
	if client == nil {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListProgramsAsClient(c.Request.Context(), client, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]TrainingProgramResponse, 0, len(list))
	for _, tp := range list {
		out = append(out, toProgramResponse(tp))
	}
	c.JSON(http.StatusOK, gin.H{"programs": out})
}

func (h *Handler) AddComment(c *gin.Context) {
	trainer := getUser(c)
	if trainer == nil {
		return
	}

	clientID, ok := parseUUIDParam(c, "client_id")
	if !ok {
		return
	}

	var req AddCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	tc, err := h.uc.AddComment(c.Request.Context(), trainer, clientID, req.Content)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toCommentResponse(tc))
}

func (h *Handler) ListComments(c *gin.Context) {
	trainerID, ok := parseUUIDParam(c, "user_id")
	if !ok {
		return
	}
	clientID, ok := parseUUIDParam(c, "client_id")
	if !ok {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListComments(c.Request.Context(), trainerID, clientID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]TrainerCommentResponse, 0, len(list))
	for _, tc := range list {
		out = append(out, toCommentResponse(tc))
	}
	c.JSON(http.StatusOK, gin.H{"comments": out})
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

func toTrainerClientResponse(tc *trainerdomain.TrainerClient) TrainerClientResponse {
	return TrainerClientResponse{
		ID:        tc.ID.String(),
		TrainerID: tc.TrainerID.String(),
		ClientID:  tc.ClientID.String(),
		Status:    tc.Status,
		CreatedAt: tc.CreatedAt.Format(time.RFC3339),
	}
}

func toProgramResponse(tp *trainerdomain.TrainingProgram) TrainingProgramResponse {
	var assignedAt *string
	if tp.AssignedAt != nil {
		s := tp.AssignedAt.Format(time.RFC3339)
		assignedAt = &s
	}
	return TrainingProgramResponse{
		ID:         tp.ID.String(),
		TrainerID:  tp.TrainerID.String(),
		ClientID:   tp.ClientID.String(),
		Name:       tp.Name,
		AssignedAt: assignedAt,
		CreatedAt:  tp.CreatedAt.Format(time.RFC3339),
	}
}

func toCommentResponse(tc *trainerdomain.TrainerComment) TrainerCommentResponse {
	return TrainerCommentResponse{
		ID:        tc.ID.String(),
		TrainerID: tc.TrainerID.String(),
		ClientID:  tc.ClientID.String(),
		Content:   tc.Content,
		CreatedAt: tc.CreatedAt.Format(time.RFC3339),
	}
}
