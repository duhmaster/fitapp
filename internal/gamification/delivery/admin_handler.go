package delivery

import (
	"encoding/json"
	"net/http"

	gamdomain "github.com/fitflow/fitflow/internal/gamification/domain"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// AdminHandler serves /api/v1/admin/gamification/* (JWT admin).
type AdminHandler struct {
	repo gamdomain.Repository
}

func NewAdminHandler(repo gamdomain.Repository) *AdminHandler {
	return &AdminHandler{repo: repo}
}

func (h *AdminHandler) GetSettings(c *gin.Context) {
	raw, err := h.repo.GetGamificationSetting(c.Request.Context(), "xp_curve")
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"key": "xp_curve", "value": json.RawMessage(raw)})
}

func (h *AdminHandler) GetLevels(c *gin.Context) {
	thresholds, err := h.repo.GetLevelThresholds(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"thresholds": thresholds})
}

func (h *AdminHandler) PatchLevels(c *gin.Context) {
	var body struct {
		Thresholds []int `json:"thresholds"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(body.Thresholds) < 2 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "thresholds must contain at least 2 values"})
		return
	}
	if err := h.repo.SetLevelThresholds(c.Request.Context(), body.Thresholds); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (h *AdminHandler) PatchSetting(c *gin.Context) {
	key := c.Param("key")
	if key == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "missing key"})
		return
	}
	var body struct {
		Value json.RawMessage `json:"value"`
	}
	if err := c.ShouldBindJSON(&body); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if len(body.Value) == 0 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "value required"})
		return
	}
	if err := h.repo.SetGamificationSetting(c.Request.Context(), key, body.Value); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (h *AdminHandler) ListBadges(c *gin.Context) {
	list, err := h.repo.ListBadgeDefinitions(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"badges": list})
}

func (h *AdminHandler) CreateBadge(c *gin.Context) {
	var req struct {
		Code        string  `json:"code" binding:"required"`
		Title       string  `json:"title" binding:"required"`
		Description *string `json:"description"`
		Rarity      string  `json:"rarity"`
		IconKey     *string `json:"icon_key"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	id, err := h.repo.CreateBadgeDefinition(c.Request.Context(), req.Code, req.Title, req.Description, req.Rarity, req.IconKey)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": id.String()})
}

func (h *AdminHandler) UpdateBadge(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	var req struct {
		Code        string  `json:"code" binding:"required"`
		Title       string  `json:"title" binding:"required"`
		Description *string `json:"description"`
		Rarity      string  `json:"rarity"`
		IconKey     *string `json:"icon_key"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.repo.UpdateBadgeDefinition(c.Request.Context(), id, req.Code, req.Title, req.Description, req.Rarity, req.IconKey); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (h *AdminHandler) DeleteBadge(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	if err := h.repo.DeleteBadgeDefinition(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (h *AdminHandler) ListMissions(c *gin.Context) {
	list, err := h.repo.ListMissionDefinitions(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"missions": list})
}

func (h *AdminHandler) CreateMission(c *gin.Context) {
	var req struct {
		Code        string  `json:"code" binding:"required"`
		Title       string  `json:"title" binding:"required"`
		Description *string `json:"description"`
		Period      string  `json:"period" binding:"required"`
		TargetValue int     `json:"target_value"`
		RewardXP    int     `json:"reward_xp"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	id, err := h.repo.CreateMissionDefinition(c.Request.Context(), req.Code, req.Title, req.Description, req.Period, req.TargetValue, req.RewardXP)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{"id": id.String()})
}

func (h *AdminHandler) UpdateMission(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	var req struct {
		Code        string  `json:"code" binding:"required"`
		Title       string  `json:"title" binding:"required"`
		Description *string `json:"description"`
		Period      string  `json:"period" binding:"required"`
		TargetValue int     `json:"target_value"`
		RewardXP    int     `json:"reward_xp"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if err := h.repo.UpdateMissionDefinition(c.Request.Context(), id, req.Code, req.Title, req.Description, req.Period, req.TargetValue, req.RewardXP); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

func (h *AdminHandler) DeleteMission(c *gin.Context) {
	id, err := uuid.Parse(c.Param("id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid id"})
		return
	}
	if err := h.repo.DeleteMissionDefinition(c.Request.Context(), id); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}
