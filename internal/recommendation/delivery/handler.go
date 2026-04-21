package delivery

import (
	"net/http"
	"strconv"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	recdomain "github.com/fitflow/fitflow/internal/recommendation/domain"
	"github.com/fitflow/fitflow/internal/recommendation/usecase"
	"github.com/gin-gonic/gin"
)

type Handler struct {
	uc *usecase.UseCase
}

func NewHandler(uc *usecase.UseCase) *Handler {
	return &Handler{uc: uc}
}

type RecommendationResponse struct {
	ID          string         `json:"id"`
	WorkoutID   string         `json:"workout_id"`
	Type        string         `json:"type"`
	Severity    string         `json:"severity"`
	Title       string         `json:"title"`
	Message     string         `json:"message"`
	Payload     map[string]any `json:"payload"`
	RuleVersion string         `json:"rule_version"`
	CreatedAt   string         `json:"created_at"`
	ExpiresAt   *string        `json:"expires_at,omitempty"`
	ReadAt      *string        `json:"read_at,omitempty"`
}

func (h *Handler) ListMine(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	list, err := h.uc.ListMine(c.Request.Context(), user, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]RecommendationResponse, 0, len(list))
	for _, rec := range list {
		out = append(out, toResponse(rec))
	}
	c.JSON(http.StatusOK, gin.H{"recommendations": out})
}

func toResponse(rec *recdomain.Recommendation) RecommendationResponse {
	var expiresAt *string
	if rec.ExpiresAt != nil {
		v := rec.ExpiresAt.UTC().Format(time.RFC3339)
		expiresAt = &v
	}
	var readAt *string
	if rec.ReadAt != nil {
		v := rec.ReadAt.UTC().Format(time.RFC3339)
		readAt = &v
	}
	return RecommendationResponse{
		ID:          rec.ID.String(),
		WorkoutID:   rec.WorkoutID.String(),
		Type:        string(rec.Type),
		Severity:    string(rec.Severity),
		Title:       rec.Title,
		Message:     rec.Message,
		Payload:     rec.Payload,
		RuleVersion: rec.RuleVersion,
		CreatedAt:   rec.CreatedAt.UTC().Format(time.RFC3339),
		ExpiresAt:   expiresAt,
		ReadAt:      readAt,
	}
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
