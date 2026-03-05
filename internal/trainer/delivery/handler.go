package delivery

import (
	"net/http"
	"strconv"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	trainerdomain "github.com/fitflow/fitflow/internal/trainer/domain"
	"github.com/fitflow/fitflow/internal/trainer/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	uc *usecase.TrainerUseCase
}

func NewHandler(uc *usecase.TrainerUseCase) *Handler {
	return &Handler{uc: uc}
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

	out := make([]TrainerClientResponse, 0, len(list))
	for _, tc := range list {
		out = append(out, toTrainerClientResponse(tc))
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

	out := make([]TrainerClientResponse, 0, len(list))
	for _, tc := range list {
		out = append(out, toTrainerClientResponse(tc))
	}
	c.JSON(http.StatusOK, gin.H{"trainers": out})
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
	trainerID, ok := parseUUIDParam(c, "trainer_id")
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
