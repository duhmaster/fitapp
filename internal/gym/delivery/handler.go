package delivery

import (
	"net/http"
	"strconv"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	"github.com/fitflow/fitflow/internal/gym/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	uc *usecase.GymUseCase
}

func NewHandler(uc *usecase.GymUseCase) *Handler {
	return &Handler{uc: uc}
}

type GymResponse struct {
	ID           string   `json:"id"`
	Name         string   `json:"name"`
	City         string   `json:"city,omitempty"`
	Latitude     *float64 `json:"latitude,omitempty"`
	Longitude    *float64 `json:"longitude,omitempty"`
	Address      string   `json:"address,omitempty"`
	ContactPhone string   `json:"contact_phone,omitempty"`
	ContactURL   string   `json:"contact_url,omitempty"`
}

type CreateGymRequest struct {
	Name         string   `json:"name" binding:"required"`
	City         string   `json:"city"`
	Latitude     *float64 `json:"latitude"`
	Longitude    *float64 `json:"longitude"`
	Address      string   `json:"address"`
	ContactPhone string   `json:"contact_phone"`
	ContactURL   string   `json:"contact_url"`
}

// AddMyGymRequest: either gym_id (link existing) or create payload.
type AddMyGymRequest struct {
	GymID        *string  `json:"gym_id"`
	Name         string   `json:"name"`
	City         string   `json:"city"`
	Address      string   `json:"address"`
	ContactPhone string   `json:"contact_phone"`
	ContactURL   string   `json:"contact_url"`
	Latitude     *float64 `json:"latitude"`
	Longitude    *float64 `json:"longitude"`
}

func (h *Handler) CreateGym(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req CreateGymRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	g, err := h.uc.CreateGym(c.Request.Context(), user, usecase.CreateGymInput{
		Name:         req.Name,
		City:         req.City,
		Address:      req.Address,
		ContactPhone: req.ContactPhone,
		ContactURL:   req.ContactURL,
		Latitude:     req.Latitude,
		Longitude:    req.Longitude,
	})
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	c.JSON(http.StatusCreated, toGymResponse(g))
}

func (h *Handler) ListMyGyms(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	gyms, err := h.uc.ListMyGyms(c.Request.Context(), user)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to list gyms"})
		return
	}
	out := make([]GymResponse, 0, len(gyms))
	for _, g := range gyms {
		out = append(out, toGymResponse(g))
	}
	c.JSON(http.StatusOK, gin.H{"gyms": out})
}

func (h *Handler) AddMyGym(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	var req AddMyGymRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
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
	var orCreate *usecase.CreateGymInput
	if gymID == nil {
		orCreate = &usecase.CreateGymInput{
			Name:         req.Name,
			City:         req.City,
			Address:      req.Address,
			ContactPhone: req.ContactPhone,
			ContactURL:   req.ContactURL,
			Latitude:     req.Latitude,
			Longitude:    req.Longitude,
		}
	}
	g, err := h.uc.AddGymToUser(c.Request.Context(), user, gymID, orCreate)
	if err != nil {
		if err == gymdomain.ErrGymNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "gym not found"})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toGymResponse(g))
}

func (h *Handler) RemoveMyGym(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	gymID, ok := parseUUIDParam(c, "gym_id")
	if !ok {
		return
	}
	if err := h.uc.RemoveGymFromUser(c.Request.Context(), user, gymID); err != nil {
		if err == gymdomain.ErrGymNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "gym not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to remove"})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) GetMyGym(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	gymID, ok := parseUUIDParam(c, "gym_id")
	if !ok {
		return
	}
	g, err := h.uc.GetMyGym(c.Request.Context(), user, gymID)
	if err != nil {
		if err == gymdomain.ErrGymNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "gym not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get gym"})
		return
	}
	c.JSON(http.StatusOK, toGymResponse(g))
}

func (h *Handler) SearchGyms(c *gin.Context) {
	q := c.Query("q")
	city := c.Query("city")

	var lat *float64
	var lng *float64
	if s := c.Query("lat"); s != "" {
		if v, err := strconv.ParseFloat(s, 64); err == nil {
			lat = &v
		}
	}
	if s := c.Query("lng"); s != "" {
		if v, err := strconv.ParseFloat(s, 64); err == nil {
			lng = &v
		}
	}

	limit := 20
	if s := c.Query("limit"); s != "" {
		if n, err := strconv.Atoi(s); err == nil {
			limit = n
		}
	}
	offset := 0
	if s := c.Query("offset"); s != "" {
		if n, err := strconv.Atoi(s); err == nil {
			offset = n
		}
	}

	gyms, err := h.uc.SearchGyms(c.Request.Context(), q, city, lat, lng, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to search gyms"})
		return
	}

	res := make([]GymResponse, 0, len(gyms))
	for _, g := range gyms {
		res = append(res, toGymResponse(g))
	}
	c.JSON(http.StatusOK, gin.H{"gyms": res})
}

func (h *Handler) CheckIn(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	gymID, ok := parseUUIDParam(c, "gym_id")
	if !ok {
		return
	}

	ci, load, err := h.uc.CheckIn(c.Request.Context(), user, gymID, time.Now())
	if err != nil {
		if err == gymdomain.ErrGymNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": "gym not found"})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": "check-in failed"})
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"check_in": gin.H{
			"id":            ci.ID.String(),
			"gym_id":        ci.GymID.String(),
			"checked_in_at": ci.CheckedInAt.Format(time.RFC3339),
		},
		"current_load": load,
	})
}

func (h *Handler) GetLoad(c *gin.Context) {
	gymID, ok := parseUUIDParam(c, "gym_id")
	if !ok {
		return
	}

	n, err := h.uc.GetLoad(c.Request.Context(), gymID, time.Now())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get load"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"gym_id": gymID.String(), "load": n})
}

func (h *Handler) GetLoadHistory(c *gin.Context) {
	gymID, ok := parseUUIDParam(c, "gym_id")
	if !ok {
		return
	}

	limit := 24
	if s := c.Query("limit"); s != "" {
		if n, err := strconv.Atoi(s); err == nil {
			limit = n
		}
	}

	hist, err := h.uc.GetLoadHistory(c.Request.Context(), gymID, limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "failed to get load history"})
		return
	}

	out := make([]gin.H, 0, len(hist))
	for _, s := range hist {
		out = append(out, gin.H{
			"hour_bucket": s.HourBucket.UTC().Format(time.RFC3339),
			"load_count":  s.LoadCount,
		})
	}
	c.JSON(http.StatusOK, gin.H{"gym_id": gymID.String(), "history": out})
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

func toGymResponse(g *gymdomain.Gym) GymResponse {
	return GymResponse{
		ID:           g.ID.String(),
		Name:         g.Name,
		City:         g.City,
		Latitude:     g.Latitude,
		Longitude:    g.Longitude,
		Address:      g.Address,
		ContactPhone: g.ContactPhone,
		ContactURL:   g.ContactURL,
	}
}

