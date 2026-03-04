package delivery

import (
	"encoding/json"
	"net/http"
	"strconv"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	notificationdomain "github.com/fitflow/fitflow/internal/notification/domain"
	"github.com/fitflow/fitflow/internal/notification/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	uc *usecase.NotificationUseCase
}

func NewHandler(uc *usecase.NotificationUseCase) *Handler {
	return &Handler{uc: uc}
}

type NotificationResponse struct {
	ID        string           `json:"id"`
	Type      string           `json:"type"`
	Payload   json.RawMessage  `json:"payload,omitempty"`
	ReadAt    *string          `json:"read_at,omitempty"`
	CreatedAt string           `json:"created_at"`
}

func (h *Handler) List(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	unreadOnly := c.Query("unread_only") == "true"
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.List(c.Request.Context(), user, unreadOnly, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]NotificationResponse, 0, len(list))
	for _, n := range list {
		out = append(out, toNotificationResponse(n))
	}
	c.JSON(http.StatusOK, gin.H{"notifications": out})
}

func (h *Handler) Get(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	id, ok := parseUUIDParam(c, "notification_id")
	if !ok {
		return
	}

	n, err := h.uc.Get(c.Request.Context(), id)
	if err != nil {
		if err == notificationdomain.ErrNotificationNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	if n.UserID != user.ID {
		c.JSON(http.StatusNotFound, gin.H{"error": "notification not found"})
		return
	}
	c.JSON(http.StatusOK, toNotificationResponse(n))
}

func (h *Handler) MarkRead(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	id, ok := parseUUIDParam(c, "notification_id")
	if !ok {
		return
	}

	n, err := h.uc.MarkRead(c.Request.Context(), user, id, time.Now().UTC())
	if err != nil {
		if err == notificationdomain.ErrNotificationNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, toNotificationResponse(n))
}

func (h *Handler) MarkAllRead(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	count, err := h.uc.MarkAllRead(c.Request.Context(), user, time.Now().UTC())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"marked": count})
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

func toNotificationResponse(n *notificationdomain.Notification) NotificationResponse {
	var readAt *string
	if n.ReadAt != nil {
		s := n.ReadAt.Format(time.RFC3339)
		readAt = &s
	}
	var payload json.RawMessage
	if len(n.Payload) > 0 {
		payload = n.Payload
	}
	return NotificationResponse{
		ID:        n.ID.String(),
		Type:      n.Type,
		Payload:   payload,
		ReadAt:    readAt,
		CreatedAt: n.CreatedAt.Format(time.RFC3339),
	}
}
