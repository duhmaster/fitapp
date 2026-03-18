package delivery

import (
	"net/http"
	"strconv"
	"time"

	systemmessagedomain "github.com/fitflow/fitflow/internal/systemmessage/domain"
	"github.com/fitflow/fitflow/internal/systemmessage/usecase"
	"github.com/gin-gonic/gin"
)

type Handler struct {
	uc *usecase.UseCase
}

func NewHandler(uc *usecase.UseCase) *Handler {
	return &Handler{uc: uc}
}

type SystemMessageResponse struct {
	ID        string `json:"id"`
	CreatedAt string `json:"created_at"`
	Title     string `json:"title"`
	Body      string `json:"body"`
	IsActive  bool   `json:"is_active"`
}

func (h *Handler) ListActive(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.List(c.Request.Context(), true, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]SystemMessageResponse, 0, len(list))
	for _, m := range list {
		out = append(out, toResponse(m))
	}
	c.JSON(http.StatusOK, gin.H{"system_messages": out})
}

func (h *Handler) CountActive(c *gin.Context) {
	n, err := h.uc.CountActive(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"count": n})
}

func toResponse(m *systemmessagedomain.SystemMessage) SystemMessageResponse {
	return SystemMessageResponse{
		ID:        m.ID.String(),
		CreatedAt: m.CreatedAt.UTC().Format(time.RFC3339),
		Title:     m.Title,
		Body:      m.Body,
		IsActive:  m.IsActive,
	}
}

