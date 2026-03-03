package delivery

import (
	"net/http"
	"strconv"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	userdomain "github.com/fitflow/fitflow/internal/user/domain"
	"github.com/fitflow/fitflow/internal/user/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler handles user HTTP requests.
type Handler struct {
	uc *usecase.UserUseCase
}

// NewHandler creates a new user Handler.
func NewHandler(uc *usecase.UserUseCase) *Handler {
	return &Handler{uc: uc}
}

// ProfileResponse is the JSON response for profile.
type ProfileResponse struct {
	ID          string  `json:"id"`
	UserID      string  `json:"user_id"`
	DisplayName string  `json:"display_name"`
	AvatarURL   string  `json:"avatar_url"`
}

// UpdateProfileRequest is the JSON body for profile update.
type UpdateProfileRequest struct {
	DisplayName string `json:"display_name"`
}

// MetricResponse is the JSON response for a metric.
type MetricResponse struct {
	ID         string   `json:"id"`
	HeightCm   *float64 `json:"height_cm,omitempty"`
	WeightKg   *float64 `json:"weight_kg,omitempty"`
	RecordedAt string   `json:"recorded_at"`
}

// RecordMetricRequest is the JSON body for recording a metric.
type RecordMetricRequest struct {
	HeightCm   *float64 `json:"height_cm"`
	WeightKg   *float64 `json:"weight_kg"`
}

// GetProfile returns the current user's profile.
func (h *Handler) GetProfile(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	profile, err := h.uc.GetProfile(c.Request.Context(), user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get profile"})
		return
	}

	c.JSON(http.StatusOK, toProfileResponse(profile))
}

// UpdateProfile updates the current user's profile.
func (h *Handler) UpdateProfile(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req UpdateProfileRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	profile, err := h.uc.UpdateProfile(c.Request.Context(), user, usecase.UpdateProfileInput{
		DisplayName: req.DisplayName,
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to update profile"})
		return
	}

	c.JSON(http.StatusOK, toProfileResponse(profile))
}

// UploadAvatar handles avatar file upload.
func (h *Handler) UploadAvatar(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	file, err := c.FormFile("avatar")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "avatar file required"})
		return
	}

	// Limit size (e.g. 5MB)
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

	url, err := h.uc.UploadAvatar(c.Request.Context(), user, ct, f)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to upload avatar"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"avatar_url": url})
}

// GetMetrics returns the current user's latest metric.
func (h *Handler) GetMetrics(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	metric, err := h.uc.GetLatestMetric(c.Request.Context(), user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get metrics"})
		return
	}
	if metric == nil {
		c.JSON(http.StatusOK, gin.H{"metric": nil})
		return
	}

	c.JSON(http.StatusOK, gin.H{"metric": toMetricResponse(metric)})
}

// GetMetricHistory returns the current user's metric history.
func (h *Handler) GetMetricHistory(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	limit := 50
	if s := c.Query("limit"); s != "" {
		if n, err := strconv.Atoi(s); err == nil && n > 0 && n <= 100 {
			limit = n
		}
	}

	metrics, err := h.uc.GetMetricHistory(c.Request.Context(), user, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get metric history"})
		return
	}

	res := make([]MetricResponse, len(metrics))
	for i, m := range metrics {
		res[i] = *toMetricResponse(m)
	}
	c.JSON(http.StatusOK, gin.H{"metrics": res})
}

// RecordMetric adds a new metric entry.
func (h *Handler) RecordMetric(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req RecordMetricRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if req.HeightCm == nil && req.WeightKg == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "height_cm or weight_kg required"})
		return
	}

	metric, err := h.uc.RecordMetric(c.Request.Context(), user, usecase.RecordMetricInput{
		HeightCm: req.HeightCm,
		WeightKg: req.WeightKg,
	})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to record metric"})
		return
	}

	c.JSON(http.StatusCreated, toMetricResponse(metric))
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

func toProfileResponse(p *userdomain.Profile) ProfileResponse {
	if p == nil {
		return ProfileResponse{}
	}
	id := ""
	if p.ID != uuid.Nil {
		id = p.ID.String()
	}
	return ProfileResponse{
		ID:          id,
		UserID:      p.UserID.String(),
		DisplayName: p.DisplayName,
		AvatarURL:   p.AvatarURL,
	}
}

func toMetricResponse(m *userdomain.Metric) *MetricResponse {
	if m == nil {
		return nil
	}
	return &MetricResponse{
		ID:         m.ID.String(),
		HeightCm:   m.HeightCm,
		WeightKg:   m.WeightKg,
		RecordedAt: m.RecordedAt.Format("2006-01-02T15:04:05Z07:00"),
	}
}
