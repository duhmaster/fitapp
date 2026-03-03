package delivery

import (
	"net/http"
	"strconv"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	progressdomain "github.com/fitflow/fitflow/internal/progress/domain"
	"github.com/fitflow/fitflow/internal/progress/usecase"
	"github.com/gin-gonic/gin"
)

type Handler struct {
	uc *usecase.ProgressUseCase
}

func NewHandler(uc *usecase.ProgressUseCase) *Handler {
	return &Handler{uc: uc}
}

type WeightResponse struct {
	ID         string `json:"id"`
	WeightKg   float64 `json:"weight_kg"`
	RecordedAt string `json:"recorded_at"`
}

type BodyFatResponse struct {
	ID          string `json:"id"`
	BodyFatPct  float64 `json:"body_fat_pct"`
	RecordedAt  string `json:"recorded_at"`
}

type HealthMetricResponse struct {
	ID         string   `json:"id"`
	MetricType string   `json:"metric_type"`
	Value      *float64 `json:"value,omitempty"`
	RecordedAt string   `json:"recorded_at"`
	Source     *string  `json:"source,omitempty"`
}

type RecordWeightRequest struct {
	WeightKg   float64 `json:"weight_kg" binding:"required"`
	RecordedAt *string `json:"recorded_at"`
}

type RecordBodyFatRequest struct {
	BodyFatPct float64 `json:"body_fat_pct" binding:"required"`
	RecordedAt *string `json:"recorded_at"`
}

type RecordHealthMetricRequest struct {
	MetricType string   `json:"metric_type" binding:"required"`
	Value      *float64 `json:"value"`
	RecordedAt *string  `json:"recorded_at"`
	Source     *string  `json:"source"`
}

func (h *Handler) RecordWeight(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req RecordWeightRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	recordedAt := time.Now().UTC()
	if req.RecordedAt != nil && *req.RecordedAt != "" {
		if t, err := time.Parse(time.RFC3339, *req.RecordedAt); err == nil {
			recordedAt = t
		}
	}

	w, err := h.uc.RecordWeight(c.Request.Context(), user, req.WeightKg, recordedAt)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toWeightResponse(w))
}

func (h *Handler) ListWeightHistory(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListWeightHistory(c.Request.Context(), user, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]WeightResponse, 0, len(list))
	for _, w := range list {
		out = append(out, toWeightResponse(w))
	}
	c.JSON(http.StatusOK, gin.H{"weight_history": out})
}

func (h *Handler) RecordBodyFat(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req RecordBodyFatRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	recordedAt := time.Now().UTC()
	if req.RecordedAt != nil && *req.RecordedAt != "" {
		if t, err := time.Parse(time.RFC3339, *req.RecordedAt); err == nil {
			recordedAt = t
		}
	}

	b, err := h.uc.RecordBodyFat(c.Request.Context(), user, req.BodyFatPct, recordedAt)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toBodyFatResponse(b))
}

func (h *Handler) ListBodyFatHistory(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListBodyFatHistory(c.Request.Context(), user, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]BodyFatResponse, 0, len(list))
	for _, b := range list {
		out = append(out, toBodyFatResponse(b))
	}
	c.JSON(http.StatusOK, gin.H{"body_fat_history": out})
}

func (h *Handler) RecordHealthMetric(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req RecordHealthMetricRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	recordedAt := time.Now().UTC()
	if req.RecordedAt != nil && *req.RecordedAt != "" {
		if t, err := time.Parse(time.RFC3339, *req.RecordedAt); err == nil {
			recordedAt = t
		}
	}

	hm, err := h.uc.RecordHealthMetric(c.Request.Context(), user, req.MetricType, req.Value, recordedAt, req.Source)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toHealthMetricResponse(hm))
}

func (h *Handler) ListHealthMetrics(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	metricType := c.Query("type")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListHealthMetrics(c.Request.Context(), user, metricType, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]HealthMetricResponse, 0, len(list))
	for _, hm := range list {
		out = append(out, toHealthMetricResponse(hm))
	}
	c.JSON(http.StatusOK, gin.H{"health_metrics": out})
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

func toWeightResponse(w *progressdomain.WeightTracking) WeightResponse {
	return WeightResponse{
		ID:         w.ID.String(),
		WeightKg:   w.WeightKg,
		RecordedAt: w.RecordedAt.Format(time.RFC3339),
	}
}

func toBodyFatResponse(b *progressdomain.BodyFatTracking) BodyFatResponse {
	return BodyFatResponse{
		ID:          b.ID.String(),
		BodyFatPct:  b.BodyFatPct,
		RecordedAt:  b.RecordedAt.Format(time.RFC3339),
	}
}

func toHealthMetricResponse(hm *progressdomain.HealthMetric) HealthMetricResponse {
	return HealthMetricResponse{
		ID:         hm.ID.String(),
		MetricType: hm.MetricType,
		Value:      hm.Value,
		RecordedAt: hm.RecordedAt.Format(time.RFC3339),
		Source:     hm.Source,
	}
}
