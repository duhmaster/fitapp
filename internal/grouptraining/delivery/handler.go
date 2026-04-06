package delivery

import (
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/fitflow/fitflow/internal/grouptraining/domain"
	"github.com/fitflow/fitflow/internal/grouptraining/usecase"
	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	uc *usecase.GroupTrainingUseCase
}

func NewHandler(uc *usecase.GroupTrainingUseCase) *Handler {
	return &Handler{uc: uc}
}

type GroupTrainingTypeResponse struct {
	ID        string `json:"id"`
	Name      string `json:"name"`
	CreatedAt string `json:"created_at"`
}

func (h *Handler) ListTypes(c *gin.Context) {
	list, err := h.uc.ListTypes(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]GroupTrainingTypeResponse, 0, len(list))
	for _, t := range list {
		out = append(out, GroupTrainingTypeResponse{
			ID:        t.ID.String(),
			Name:      t.Name,
			CreatedAt: t.CreatedAt.UTC().Format(time.RFC3339),
		})
	}
	c.JSON(http.StatusOK, gin.H{"types": out})
}

// GetPublicGroupTraining — GET /group-trainings/:training_id (no auth). Future trainings only.
func (h *Handler) GetPublicGroupTraining(c *gin.Context) {
	trainingID, ok := parseUUIDParam(c, "training_id")
	if !ok {
		return
	}
	item, err := h.uc.GetPublicTrainingLanding(c.Request.Context(), trainingID)
	if err != nil {
		if err == domain.ErrGroupTrainingNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"landing": toBookingItemResponse(item)})
}

// ListUpcomingForTrainerPublic — GET /trainers/:user_id/group-trainings/upcoming (no auth).
func (h *Handler) ListUpcomingForTrainerPublic(c *gin.Context) {
	trainerID, ok := parseUUIDParam(c, "user_id")
	if !ok {
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListUpcomingForTrainer(c.Request.Context(), trainerID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]GroupTrainingBookingItemResponse, 0, len(list))
	for _, it := range list {
		out = append(out, toBookingItemResponse(it))
	}
	c.JSON(http.StatusOK, gin.H{"trainings": out})
}

// ---- Templates (trainer) ----

type GroupTrainingTemplateCreateRequest struct {
	Name               string   `json:"name" binding:"required"`
	Description        string   `json:"description"`
	DurationMinutes    int      `json:"duration_minutes"`
	Equipment          []string `json:"equipment"`
	LevelOfPreparation string   `json:"level_of_preparation"`
	PhotoPath          *string  `json:"photo_path"` // legacy: external URL
	PhotoID            *string  `json:"photo_id"`   // legacy single id when photo_ids omitted
	PhotoIDs           []string `json:"photo_ids"`  // gallery (max 3); if key sent, replaces gallery (empty clears)
	MaxPeopleCount     int      `json:"max_people_count"`
	GroupTypeID        string   `json:"group_type_id" binding:"required"`
	IsActive           bool     `json:"is_active"`
}

type GroupTrainingTemplateUpdateRequest = GroupTrainingTemplateCreateRequest

// parseTemplateGalleryPhotoIDs builds an ordered unique gallery from the request.
// If photo_ids was sent in JSON (including empty array), it defines the gallery.
// If photo_ids is omitted (nil), legacy photo_id is used when set.
func parseTemplateGalleryPhotoIDs(req *GroupTrainingTemplateCreateRequest) ([]uuid.UUID, error) {
	if req.PhotoIDs != nil {
		seen := make(map[uuid.UUID]struct{})
		out := make([]uuid.UUID, 0, len(req.PhotoIDs))
		for _, s := range req.PhotoIDs {
			if s == "" {
				continue
			}
			id, err := uuid.Parse(s)
			if err != nil {
				return nil, err
			}
			if _, ok := seen[id]; ok {
				continue
			}
			seen[id] = struct{}{}
			out = append(out, id)
		}
		if len(out) > domain.MaxPhotosPerGroupTrainingTemplate {
			return nil, domain.ErrGroupTrainingTemplateTooManyPhotos
		}
		return out, nil
	}
	if req.PhotoID != nil && *req.PhotoID != "" {
		id, err := uuid.Parse(*req.PhotoID)
		if err != nil {
			return nil, err
		}
		return []uuid.UUID{id}, nil
	}
	return []uuid.UUID{}, nil
}

type GroupTrainingTemplateResponse struct {
	ID                 string   `json:"id"`
	Name               string   `json:"name"`
	Description        string   `json:"description"`
	DurationMinutes    int      `json:"duration_minutes"`
	Equipment          []string `json:"equipment"`
	LevelOfPreparation string   `json:"level_of_preparation"`
	PhotoPath          *string  `json:"photo_path"` // primary/first URL (compat)
	PhotoID            *string  `json:"photo_id,omitempty"`
	PhotoPaths         []string `json:"photo_paths,omitempty"`
	PhotoIDs           []string `json:"photo_ids,omitempty"`
	MaxPeopleCount     int      `json:"max_people_count"`
	TrainerUserID      string   `json:"trainer_user_id"`
	IsActive           bool     `json:"is_active"`
	GroupTypeID        string   `json:"group_type_id"`
	CreatedAt          string   `json:"created_at"`
	UpdatedAt          string   `json:"updated_at"`
}

func (h *Handler) ListTrainerTemplates(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListTrainerTemplates(c.Request.Context(), user.ID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]GroupTrainingTemplateResponse, 0, len(list))
	for _, t := range list {
		out = append(out, toGroupTrainingTemplateResponse(t))
	}
	c.JSON(http.StatusOK, gin.H{"templates": out})
}

func (h *Handler) GetTrainerTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateID, ok := parseUUIDParam(c, "template_id")
	if !ok {
		return
	}
	t, err := h.uc.GetTrainerTemplate(c.Request.Context(), user.ID, templateID)
	if err != nil {
		if err == domain.ErrGroupTrainingTemplateNotFound || err == domain.ErrGroupTrainingTemplateForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"template": toGroupTrainingTemplateResponse(t)})
}

func (h *Handler) CreateTrainerTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	var req GroupTrainingTemplateCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	groupTypeID, err := uuid.Parse(req.GroupTypeID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid group_type_id"})
		return
	}
	gallery, err := parseTemplateGalleryPhotoIDs(&req)
	if err != nil {
		if errors.Is(err, domain.ErrGroupTrainingTemplateTooManyPhotos) {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid photo_ids"})
		return
	}

	t, err := h.uc.CreateTemplate(
		c.Request.Context(),
		user.ID,
		req.Name,
		req.Description,
		req.DurationMinutes,
		req.Equipment,
		req.LevelOfPreparation,
		req.PhotoPath,
		gallery,
		req.MaxPeopleCount,
		groupTypeID,
		req.IsActive,
	)
	if err != nil {
		if errors.Is(err, domain.ErrGroupTrainingTemplateTooManyPhotos) {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"template": toGroupTrainingTemplateResponse(t)})
}

func (h *Handler) UpdateTrainerTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateID, ok := parseUUIDParam(c, "template_id")
	if !ok {
		return
	}
	var req GroupTrainingTemplateUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	groupTypeID, err := uuid.Parse(req.GroupTypeID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid group_type_id"})
		return
	}
	gallery, err := parseTemplateGalleryPhotoIDs(&req)
	if err != nil {
		if errors.Is(err, domain.ErrGroupTrainingTemplateTooManyPhotos) {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid photo_ids"})
		return
	}

	t, err := h.uc.UpdateTemplate(
		c.Request.Context(),
		user.ID,
		templateID,
		req.Name,
		req.Description,
		req.DurationMinutes,
		req.Equipment,
		req.LevelOfPreparation,
		req.PhotoPath,
		gallery,
		req.MaxPeopleCount,
		groupTypeID,
		req.IsActive,
	)
	if err != nil {
		if err == domain.ErrGroupTrainingTemplateNotFound || err == domain.ErrGroupTrainingTemplateForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		if errors.Is(err, domain.ErrGroupTrainingTemplateTooManyPhotos) {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"template": toGroupTrainingTemplateResponse(t)})
}

func (h *Handler) SoftDeleteTrainerTemplate(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	templateID, ok := parseUUIDParam(c, "template_id")
	if !ok {
		return
	}
	if err := h.uc.SoftDeleteTemplate(c.Request.Context(), user.ID, templateID); err != nil {
		if err == domain.ErrGroupTrainingTemplateNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

// ---- Group trainings (trainer) ----

type GroupTrainingCreateRequest struct {
	TemplateID   string `json:"template_id" binding:"required"`
	ScheduledAt string `json:"scheduled_at" binding:"required"`
	GymID        string `json:"gym_id" binding:"required"`
}

type GroupTrainingUpdateRequest = GroupTrainingCreateRequest

type GroupTrainingResponse struct {
	ID             string `json:"id"`
	TemplateID     string `json:"template_id"`
	TemplateName   string `json:"template_name"`
	ScheduledAt    string `json:"scheduled_at"`
	TrainerUserID  string `json:"trainer_user_id"`
	GymID          string `json:"gym_id"`
	City           string `json:"city"`
	CreatedAt      string `json:"created_at"`
	UpdatedAt      string `json:"updated_at"`
}

func (h *Handler) ListTrainerTrainings(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	includePast, _ := strconv.Atoi(c.DefaultQuery("includePast", "0"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListTrainerTrainings(c.Request.Context(), user.ID, includePast == 1, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]GroupTrainingResponse, 0, len(list))
	for _, t := range list {
		out = append(out, toGroupTrainingResponse(t))
	}
	c.JSON(http.StatusOK, gin.H{"trainings": out})
}

func (h *Handler) CreateTrainerTraining(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	var req GroupTrainingCreateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	templateID, err := uuid.Parse(req.TemplateID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid template_id"})
		return
	}
	gymID, err := uuid.Parse(req.GymID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid gym_id"})
		return
	}
	scheduledAt, err := time.Parse(time.RFC3339, req.ScheduledAt)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid scheduled_at"})
		return
	}

	tr, err := h.uc.CreateTraining(c.Request.Context(), user.ID, templateID, gymID, scheduledAt.UTC())
	if err != nil {
		if err == domain.ErrGroupTrainingTemplateNotFound || err == domain.ErrGroupTrainingTemplateForbidden {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		if err == domain.ErrFreeUserWeeklyLimitReached {
			c.JSON(http.StatusForbidden, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"training": toGroupTrainingResponse(tr)})
}

func (h *Handler) UpdateTrainerTraining(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	trainingID, ok := parseUUIDParam(c, "training_id")
	if !ok {
		return
	}

	var req GroupTrainingUpdateRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	templateID, err := uuid.Parse(req.TemplateID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid template_id"})
		return
	}
	gymID, err := uuid.Parse(req.GymID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid gym_id"})
		return
	}
	scheduledAt, err := time.Parse(time.RFC3339, req.ScheduledAt)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid scheduled_at"})
		return
	}

	tr, err := h.uc.UpdateTraining(c.Request.Context(), user.ID, trainingID, templateID, gymID, scheduledAt.UTC())
	if err != nil {
		switch {
		case err == domain.ErrGroupTrainingTemplateNotFound || err == domain.ErrGroupTrainingTemplateForbidden:
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		case err == domain.ErrGroupTrainingNotFound:
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"training": toGroupTrainingResponse(tr)})
}

func (h *Handler) GetTrainerTraining(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	trainingID, ok := parseUUIDParam(c, "training_id")
	if !ok {
		return
	}
	tr, err := h.uc.GetTrainingForTrainer(c.Request.Context(), user.ID, trainingID)
	if err != nil {
		if err == domain.ErrGroupTrainingNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	participants, err := h.uc.ListParticipantsForTrainer(c.Request.Context(), user.ID, trainingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	payload := gin.H{
		"training":     toGroupTrainingResponse(tr),
		"participants": participantsToResponse(participants),
	}
	if disp, err := h.uc.GetTrainingBookingDisplay(c.Request.Context(), trainingID); err == nil && disp != nil {
		br := toBookingItemResponse(disp)
		payload["display"] = br
	}
	c.JSON(http.StatusOK, payload)
}

func (h *Handler) DeleteTrainerTraining(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	trainingID, ok := parseUUIDParam(c, "training_id")
	if !ok {
		return
	}
	if err := h.uc.DeleteTraining(c.Request.Context(), user.ID, trainingID); err != nil {
		if err == domain.ErrGroupTrainingNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

// ---- Group trainings (user) ----

func (h *Handler) ListUserTrainings(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	includePast, _ := strconv.Atoi(c.DefaultQuery("includePast", "0"))
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListUserTrainings(c.Request.Context(), user.ID, includePast == 1, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]GroupTrainingResponse, 0, len(list))
	for _, t := range list {
		out = append(out, toGroupTrainingResponse(t))
	}
	c.JSON(http.StatusOK, gin.H{"trainings": out})
}

func (h *Handler) GetUserTraining(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	trainingID, ok := parseUUIDParam(c, "training_id")
	if !ok {
		return
	}
	tr, err := h.uc.GetTrainingForUser(c.Request.Context(), user.ID, trainingID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
		return
	}
	participants, err := h.uc.ListParticipantsForUser(c.Request.Context(), user.ID, trainingID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	payload := gin.H{
		"training":     toGroupTrainingResponse(tr),
		"participants": participantsToResponse(participants),
	}
	if disp, err := h.uc.GetTrainingBookingDisplay(c.Request.Context(), trainingID); err == nil && disp != nil {
		br := toBookingItemResponse(disp)
		payload["display"] = br
	}
	c.JSON(http.StatusOK, payload)
}

func (h *Handler) RegisterForTraining(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	trainingID, ok := parseUUIDParam(c, "training_id")
	if !ok {
		return
	}
	if err := h.uc.RegisterUser(c.Request.Context(), user.ID, trainingID); err != nil {
		switch {
		case err == domain.ErrRegistrationAlreadyExists:
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		case err == domain.ErrGroupTrainingFull:
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		}
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) UnregisterFromTraining(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	trainingID, ok := parseUUIDParam(c, "training_id")
	if !ok {
		return
	}
	if err := h.uc.UnregisterUser(c.Request.Context(), user.ID, trainingID); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

type GroupTrainingBookingItemResponse struct {
	TrainingID           string   `json:"training_id"`
	TemplateID           string   `json:"template_id"`
	TemplateName         string   `json:"template_name"`
	Description          string   `json:"description"`
	DurationMinutes      int      `json:"duration_minutes"`
	Equipment            []string `json:"equipment"`
	LevelOfPreparation   string   `json:"level_of_preparation"`
	PhotoPath            *string  `json:"photo_path"`
	MaxPeopleCount       int      `json:"max_people_count"`
	GroupTypeID          string   `json:"group_type_id"`
	GroupTypeName        string   `json:"group_type_name"`
	ScheduledAt          string   `json:"scheduled_at"`
	TrainerUserID        string   `json:"trainer_user_id"`
	GymID                string   `json:"gym_id"`
	City                 string   `json:"city"`
	ParticipantsCount    int      `json:"participants_count"`
}

func (h *Handler) ListAvailableForUser(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	var city *string
	if v := c.Query("city"); v != "" {
		city = &v
	}
	var gymID *uuid.UUID
	if v := c.Query("gym_id"); v != "" {
		id, err := uuid.Parse(v)
		if err == nil {
			gymID = &id
		}
	}
	var trainerUserID *uuid.UUID
	if v := c.Query("trainer_user_id"); v != "" {
		id, err := uuid.Parse(v)
		if err == nil {
			trainerUserID = &id
		}
	}
	var groupTypeID *uuid.UUID
	if v := c.Query("group_type_id"); v != "" {
		id, err := uuid.Parse(v)
		if err == nil {
			groupTypeID = &id
		}
	}
	var dateFrom *time.Time
	if v := c.Query("date_from"); v != "" {
		t, err := time.Parse(time.RFC3339, v)
		if err == nil {
			dateFrom = &t
		}
	}
	var dateTo *time.Time
	if v := c.Query("date_to"); v != "" {
		t, err := time.Parse(time.RFC3339, v)
		if err == nil {
			dateTo = &t
		}
	}

	list, err := h.uc.ListAvailableForUser(
		c.Request.Context(),
		user.ID,
		city,
		gymID,
		trainerUserID,
		dateFrom,
		dateTo,
		groupTypeID,
		limit,
		offset,
	)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]GroupTrainingBookingItemResponse, 0, len(list))
	for _, it := range list {
		out = append(out, toBookingItemResponse(it))
	}
	c.JSON(http.StatusOK, gin.H{"available": out})
}

// ---- helpers / mapping ----

type ParticipantProfileResponse struct {
	UserID      string  `json:"user_id"`
	DisplayName *string `json:"display_name"`
	City        *string `json:"city"`
	AvatarURL   *string `json:"avatar_url"`
}

func participantsToResponse(list []*domain.ParticipantProfile) []ParticipantProfileResponse {
	out := make([]ParticipantProfileResponse, 0, len(list))
	for _, p := range list {
		out = append(out, ParticipantProfileResponse{
			UserID:      p.UserID.String(),
			DisplayName: p.DisplayName,
			City:        p.City,
			AvatarURL:   p.AvatarURL,
		})
	}
	return out
}

func toGroupTrainingTemplateResponse(t *domain.GroupTrainingTemplate) GroupTrainingTemplateResponse {
	resp := GroupTrainingTemplateResponse{
		ID:                 t.ID.String(),
		Name:               t.Name,
		Description:        t.Description,
		DurationMinutes:    t.DurationMinutes,
		Equipment:          t.Equipment,
		LevelOfPreparation: t.LevelOfPreparation,
		PhotoPath:          t.PhotoPath,
		MaxPeopleCount:     t.MaxPeopleCount,
		TrainerUserID:      t.TrainerUserID.String(),
		IsActive:           t.IsActive,
		GroupTypeID:        t.GroupTypeID.String(),
		CreatedAt:          t.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt:          t.UpdatedAt.UTC().Format(time.RFC3339),
	}
	if t.PhotoID != nil {
		s := t.PhotoID.String()
		resp.PhotoID = &s
	}
	if len(t.GalleryPhotoIDs) > 0 {
		ids := make([]string, 0, len(t.GalleryPhotoIDs))
		for _, id := range t.GalleryPhotoIDs {
			ids = append(ids, id.String())
		}
		resp.PhotoIDs = ids
	}
	if len(t.GalleryPhotoURLs) > 0 {
		resp.PhotoPaths = append([]string(nil), t.GalleryPhotoURLs...)
	}
	return resp
}

func toGroupTrainingResponse(t *domain.GroupTraining) GroupTrainingResponse {
	return GroupTrainingResponse{
		ID:             t.ID.String(),
		TemplateID:     t.TemplateID.String(),
		TemplateName:   t.TemplateName,
		ScheduledAt:    t.ScheduledAt.UTC().Format(time.RFC3339),
		TrainerUserID:  t.TrainerUserID.String(),
		GymID:          t.GymID.String(),
		City:           t.City,
		CreatedAt:      t.CreatedAt.UTC().Format(time.RFC3339),
		UpdatedAt:      t.UpdatedAt.UTC().Format(time.RFC3339),
	}
}

func toBookingItemResponse(it *domain.GroupTrainingBookingItem) GroupTrainingBookingItemResponse {
	return GroupTrainingBookingItemResponse{
		TrainingID:        it.TrainingID.String(),
		TemplateID:        it.TemplateID.String(),
		TemplateName:      it.TemplateName,
		Description:       it.Description,
		DurationMinutes:   it.DurationMinutes,
		Equipment:         it.Equipment,
		LevelOfPreparation: it.LevelOfPreparation,
		PhotoPath:         it.PhotoPath,
		MaxPeopleCount:    it.MaxPeopleCount,
		GroupTypeID:       it.GroupTypeID.String(),
		GroupTypeName:     it.GroupTypeName,
		ScheduledAt:       it.ScheduledAt.UTC().Format(time.RFC3339),
		TrainerUserID:     it.TrainerUserID.String(),
		GymID:             it.GymID.String(),
		City:              it.City,
		ParticipantsCount: it.ParticipantsCount,
	}
}

type TrainerAtGymResponse struct {
	UserID      string `json:"user_id"`
	DisplayName string `json:"display_name"`
}

// ListTrainersAtGym — GET /gyms/:gym_id/trainers (public).
func (h *Handler) ListTrainersAtGym(c *gin.Context) {
	gymID, ok := parseUUIDParam(c, "gym_id")
	if !ok {
		return
	}
	list, err := h.uc.ListTrainersAtGym(c.Request.Context(), gymID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]TrainerAtGymResponse, 0, len(list))
	for _, t := range list {
		out = append(out, TrainerAtGymResponse{
			UserID:      t.UserID.String(),
			DisplayName: t.DisplayName,
		})
	}
	c.JSON(http.StatusOK, gin.H{"trainers": out})
}

// ListGroupTrainingsByGym — GET /gyms/:gym_id/group-trainings (public). Ordered by scheduled_at ascending.
func (h *Handler) ListGroupTrainingsByGym(c *gin.Context) {
	gymID, ok := parseUUIDParam(c, "gym_id")
	if !ok {
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "100"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))
	list, err := h.uc.ListGroupTrainingsByGym(c.Request.Context(), gymID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]GroupTrainingResponse, 0, len(list))
	for _, t := range list {
		out = append(out, toGroupTrainingResponse(t))
	}
	c.JSON(http.StatusOK, gin.H{"trainings": out})
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

