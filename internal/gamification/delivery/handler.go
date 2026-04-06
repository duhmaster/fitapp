package delivery

import (
	"net/http"
	"strconv"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	gamdomain "github.com/fitflow/fitflow/internal/gamification/domain"
	"github.com/fitflow/fitflow/internal/gamification/usecase"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler serves /api/v1/me/gamification/*.
type Handler struct {
	uc *usecase.UseCase
}

func NewHandler(uc *usecase.UseCase) *Handler {
	return &Handler{uc: uc}
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

// GET /me/gamification/profile
func (h *Handler) GetProfile(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	p, err := h.uc.GetProfile(c.Request.Context(), user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, profileJSON(p))
}

func profileJSON(p *gamdomain.Profile) gin.H {
	out := gin.H{
		"user_id":                 p.UserID.String(),
		"total_xp":                p.TotalXP,
		"level":                   p.Level,
		"xp_into_current_level":   p.XPIntoCurrentLevel,
		"xp_for_next_level":       p.XPForNextLevel,
		"avatar_tier":             p.AvatarTier,
	}
	if p.DisplayTitle != nil {
		out["display_title"] = *p.DisplayTitle
	}
	return out
}

// GET /me/gamification/xp-history
func (h *Handler) GetXPHistory(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	limit, _ := strconv.Atoi(c.Query("limit"))
	offset, _ := strconv.Atoi(c.Query("offset"))
	rows, err := h.uc.ListXPHistory(c.Request.Context(), user.ID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	items := make([]gin.H, 0, len(rows))
	for _, x := range rows {
		m := gin.H{
			"id":               x.ID.String(),
			"delta_xp":         x.DeltaXP,
			"reason":           x.Reason,
			"created_at":       x.CreatedAt.UTC().Format(time.RFC3339),
			"idempotency_key":  x.IdempotencyKey,
		}
		if x.SourceType != nil {
			m["source_type"] = *x.SourceType
		}
		if x.SourceID != nil {
			m["source_id"] = x.SourceID.String()
		}
		items = append(items, m)
	}
	c.JSON(http.StatusOK, gin.H{"items": items, "xp_events": items})
}

// GET /me/gamification/badges/catalog
func (h *Handler) GetBadgeCatalog(c *gin.Context) {
	if getUser(c) == nil {
		return
	}
	list, err := h.uc.ListBadgeCatalog(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	badges := make([]gin.H, 0, len(list))
	for _, b := range list {
		hm := gin.H{
			"id":     b.ID.String(),
			"code":   b.Code,
			"title":  b.Title,
			"rarity": b.Rarity,
		}
		if b.Description != nil {
			hm["description"] = *b.Description
		}
		if b.IconKey != nil {
			hm["icon_key"] = *b.IconKey
		}
		badges = append(badges, hm)
	}
	c.JSON(http.StatusOK, gin.H{"badges": badges})
}

// GET /me/gamification/badges
func (h *Handler) GetUserBadges(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	list, err := h.uc.ListUserBadges(c.Request.Context(), user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	items := make([]gin.H, 0, len(list))
	for _, ub := range list {
		items = append(items, gin.H{
			"badge_id":     ub.BadgeID.String(),
			"unlocked_at":  ub.UnlockedAt.UTC().Format(time.RFC3339),
		})
	}
	c.JSON(http.StatusOK, gin.H{"user_badges": items, "items": items})
}

// GET /me/gamification/missions
func (h *Handler) GetMissions(c *gin.Context) {
	if getUser(c) == nil {
		return
	}
	list, err := h.uc.ListMissionDefinitions(c.Request.Context())
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	missions := make([]gin.H, 0, len(list))
	for _, m := range list {
		hm := gin.H{
			"id":            m.ID.String(),
			"code":          m.Code,
			"title":         m.Title,
			"period":        m.Period,
			"target_value":  m.TargetValue,
			"reward_xp":     m.RewardXP,
		}
		if m.Description != nil {
			hm["description"] = *m.Description
		}
		missions = append(missions, hm)
	}
	c.JSON(http.StatusOK, gin.H{"missions": missions})
}

// GET /me/gamification/missions/progress
func (h *Handler) GetMissionProgress(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	list, err := h.uc.ListMissionProgress(c.Request.Context(), user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	progress := make([]gin.H, 0, len(list))
	for _, p := range list {
		hm := gin.H{
			"mission_id":    p.MissionID.String(),
			"current_value": p.CurrentValue,
			"status":        string(p.Status),
		}
		if p.WindowStart != nil {
			hm["window_start"] = p.WindowStart.UTC().Format(time.RFC3339)
		}
		if p.WindowEnd != nil {
			hm["window_end"] = p.WindowEnd.UTC().Format(time.RFC3339)
		}
		progress = append(progress, hm)
	}
	c.JSON(http.StatusOK, gin.H{"progress": progress})
}

// POST /me/gamification/missions/:mission_id/claim
func (h *Handler) ClaimMission(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	mid, err := uuid.Parse(c.Param("mission_id"))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid mission_id"})
		return
	}
	err = h.uc.ClaimMission(c.Request.Context(), user.ID, mid)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"ok": true})
}

// GET /me/gamification/leaderboards
func (h *Handler) GetLeaderboards(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	scope := c.DefaultQuery("scope", "global")
	if scope == "trainer" {
		scope = "trainer_clients"
	}
	period := c.DefaultQuery("period", "weekly")
	if period == "week" {
		period = "weekly"
	}
	limit, _ := strconv.Atoi(c.Query("limit"))
	var gymID *uuid.UUID
	if raw := c.Query("gym_id"); raw != "" {
		id, err := uuid.Parse(raw)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid gym_id"})
			return
		}
		gymID = &id
	}
	entries, err := h.uc.Leaderboard(c.Request.Context(), user.ID, scope, period, gymID, limit)
	if err != nil {
		if err == usecase.ErrGymIDRequired {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]gin.H, 0, len(entries))
	for _, e := range entries {
		hm := gin.H{
			"rank":             e.Rank,
			"user_id":          e.UserID.String(),
			"display_name":     e.DisplayName,
			"score":            e.Score,
			"is_current_user":  e.IsCurrentUser,
		}
		if e.AvatarURL != nil {
			hm["avatar_url"] = *e.AvatarURL
		}
		out = append(out, hm)
	}
	c.JSON(http.StatusOK, gin.H{"entries": out, "items": out})
}

// GET /me/gamification/preferences
func (h *Handler) GetFeaturePreferences(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	p, err := h.uc.GetUserFeaturePreferences(c.Request.Context(), user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"xp_enabled":               p.XPEnabled,
		"badges_enabled":           p.BadgesEnabled,
		"leaderboard_enabled":      p.LeaderboardEnabled,
		"trainer_ranking_enabled": p.TrainerRankingEnabled,
	})
}

type patchFeaturePreferencesBody struct {
	XPEnabled             *bool `json:"xp_enabled"`
	BadgesEnabled         *bool `json:"badges_enabled"`
	LeaderboardEnabled    *bool `json:"leaderboard_enabled"`
	TrainerRankingEnabled *bool `json:"trainer_ranking_enabled"`
}

// PATCH /me/gamification/preferences — partial update; omitted fields keep current values.
func (h *Handler) PatchFeaturePreferences(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}
	cur, err := h.uc.GetUserFeaturePreferences(c.Request.Context(), user.ID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	var req patchFeaturePreferencesBody
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	if req.XPEnabled != nil {
		cur.XPEnabled = *req.XPEnabled
	}
	if req.BadgesEnabled != nil {
		cur.BadgesEnabled = *req.BadgesEnabled
	}
	if req.LeaderboardEnabled != nil {
		cur.LeaderboardEnabled = *req.LeaderboardEnabled
	}
	if req.TrainerRankingEnabled != nil {
		cur.TrainerRankingEnabled = *req.TrainerRankingEnabled
	}
	if err := h.uc.UpsertUserFeaturePreferences(c.Request.Context(), user.ID, cur); err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"xp_enabled":               cur.XPEnabled,
		"badges_enabled":           cur.BadgesEnabled,
		"leaderboard_enabled":      cur.LeaderboardEnabled,
		"trainer_ranking_enabled": cur.TrainerRankingEnabled,
	})
}

// GET /api/v1/gamification/leaderboards/public — no auth; scores only (no PII).
func (h *Handler) GetPublicLeaderboard(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	rows, err := h.uc.PublicLeaderboardScores(c.Request.Context(), limit)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	out := make([]gin.H, 0, len(rows))
	for _, r := range rows {
		out = append(out, gin.H{"rank": r.Rank, "score": r.Score})
	}
	c.JSON(http.StatusOK, gin.H{"entries": out, "items": out})
}
