package delivery

import (
	"net/http"
	"strconv"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	socialdomain "github.com/fitflow/fitflow/internal/social/domain"
	"github.com/fitflow/fitflow/internal/social/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	uc *usecase.SocialUseCase
}

func NewHandler(uc *usecase.SocialUseCase) *Handler {
	return &Handler{uc: uc}
}

type PostResponse struct {
	ID        string  `json:"id"`
	UserID    string  `json:"user_id"`
	Content   *string `json:"content,omitempty"`
	CreatedAt string  `json:"created_at"`
}

type CommentResponse struct {
	ID        string `json:"id"`
	UserID    string `json:"user_id"`
	Content   string `json:"content"`
	CreatedAt string `json:"created_at"`
}

type CreatePostRequest struct {
	Content *string `json:"content"`
}

type AddCommentRequest struct {
	Content string `json:"content" binding:"required"`
}

func (h *Handler) Follow(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	targetID, ok := parseUUIDParam(c, "user_id")
	if !ok {
		return
	}

	_, err := h.uc.Follow(c.Request.Context(), user, targetID)
	if err != nil {
		if err == socialdomain.ErrFollowSelf || err == socialdomain.ErrAlreadyFollowing {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) Unfollow(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	targetID, ok := parseUUIDParam(c, "user_id")
	if !ok {
		return
	}

	err := h.uc.Unfollow(c.Request.Context(), user, targetID)
	if err != nil {
		if err == socialdomain.ErrNotFollowing {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) ListFollowing(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	ids, err := h.uc.ListFollowing(c.Request.Context(), user, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	strs := make([]string, 0, len(ids))
	for _, id := range ids {
		strs = append(strs, id.String())
	}
	c.JSON(http.StatusOK, gin.H{"following": strs})
}

func (h *Handler) ListFollowers(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	ids, err := h.uc.ListFollowers(c.Request.Context(), user, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	strs := make([]string, 0, len(ids))
	for _, id := range ids {
		strs = append(strs, id.String())
	}
	c.JSON(http.StatusOK, gin.H{"followers": strs})
}

func (h *Handler) CreateFriendRequest(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req struct {
		ToUserID string `json:"to_user_id" binding:"required"`
	}
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	toID, err := uuid.Parse(req.ToUserID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid to_user_id"})
		return
	}

	fr, err := h.uc.CreateFriendRequest(c.Request.Context(), user, toID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, gin.H{
		"id":          fr.ID.String(),
		"from_user_id": fr.FromUserID.String(),
		"to_user_id":   fr.ToUserID.String(),
		"status":      fr.Status,
		"created_at":  fr.CreatedAt.Format(time.RFC3339),
	})
}

func (h *Handler) ListIncomingFriendRequests(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	status := c.Query("status")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListIncomingFriendRequests(c.Request.Context(), user, status, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]gin.H, 0, len(list))
	for _, fr := range list {
		out = append(out, gin.H{
			"id":           fr.ID.String(),
			"from_user_id": fr.FromUserID.String(),
			"to_user_id":   fr.ToUserID.String(),
			"status":       fr.Status,
			"created_at":   fr.CreatedAt.Format(time.RFC3339),
		})
	}
	c.JSON(http.StatusOK, gin.H{"friend_requests": out})
}

func (h *Handler) ListOutgoingFriendRequests(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	status := c.Query("status")
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListOutgoingFriendRequests(c.Request.Context(), user, status, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]gin.H, 0, len(list))
	for _, fr := range list {
		out = append(out, gin.H{
			"id":           fr.ID.String(),
			"from_user_id": fr.FromUserID.String(),
			"to_user_id":   fr.ToUserID.String(),
			"status":       fr.Status,
			"created_at":   fr.CreatedAt.Format(time.RFC3339),
		})
	}
	c.JSON(http.StatusOK, gin.H{"friend_requests": out})
}

func (h *Handler) AcceptFriendRequest(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	reqID, ok := parseUUIDParam(c, "request_id")
	if !ok {
		return
	}

	fr, err := h.uc.AcceptFriendRequest(c.Request.Context(), user, reqID)
	if err != nil {
		if err == socialdomain.ErrFriendRequestNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"id":           fr.ID.String(),
		"from_user_id": fr.FromUserID.String(),
		"to_user_id":   fr.ToUserID.String(),
		"status":       fr.Status,
		"created_at":   fr.CreatedAt.Format(time.RFC3339),
	})
}

func (h *Handler) RejectFriendRequest(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	reqID, ok := parseUUIDParam(c, "request_id")
	if !ok {
		return
	}

	fr, err := h.uc.RejectFriendRequest(c.Request.Context(), user, reqID)
	if err != nil {
		if err == socialdomain.ErrFriendRequestNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"id":           fr.ID.String(),
		"from_user_id": fr.FromUserID.String(),
		"to_user_id":   fr.ToUserID.String(),
		"status":       fr.Status,
		"created_at":   fr.CreatedAt.Format(time.RFC3339),
	})
}

func (h *Handler) CreatePost(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req CreatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	p, err := h.uc.CreatePost(c.Request.Context(), user, req.Content)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toPostResponse(p))
}

func (h *Handler) GetFeed(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.GetFeed(c.Request.Context(), user, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]PostResponse, 0, len(list))
	for _, p := range list {
		out = append(out, toPostResponse(p))
	}
	c.JSON(http.StatusOK, gin.H{"feed": out})
}

func (h *Handler) ListUserPosts(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	userIDParam := c.Param("user_id")
	var userID uuid.UUID
	if userIDParam == "me" {
		userID = user.ID
	} else {
		var err error
		userID, err = uuid.Parse(userIDParam)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid user_id"})
			return
		}
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListUserPosts(c.Request.Context(), userID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]PostResponse, 0, len(list))
	for _, p := range list {
		out = append(out, toPostResponse(p))
	}
	c.JSON(http.StatusOK, gin.H{"posts": out})
}

func (h *Handler) GetPost(c *gin.Context) {
	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	p, err := h.uc.GetPost(c.Request.Context(), postID)
	if err != nil {
		if err == socialdomain.ErrPostNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	likeCount, _ := h.uc.GetLikeCount(c.Request.Context(), usecase.TargetTypePost, postID)
	liked := false
	if user := getUserOptional(c); user != nil {
		liked, _ = h.uc.IsLiked(c.Request.Context(), user, usecase.TargetTypePost, postID)
	}

	c.JSON(http.StatusOK, gin.H{
		"post":       toPostResponse(p),
		"like_count": likeCount,
		"liked":      liked,
	})
}

func (h *Handler) LikePost(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	_, err := h.uc.Like(c.Request.Context(), user, usecase.TargetTypePost, postID)
	if err != nil {
		if err == socialdomain.ErrAlreadyLiked {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) UnlikePost(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	err := h.uc.Unlike(c.Request.Context(), user, usecase.TargetTypePost, postID)
	if err != nil {
		if err == socialdomain.ErrNotLiked {
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) GetPostLikes(c *gin.Context) {
	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	count, err := h.uc.GetLikeCount(c.Request.Context(), usecase.TargetTypePost, postID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, gin.H{"like_count": count})
}

func (h *Handler) AddComment(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	var req AddCommentRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	comment, err := h.uc.AddComment(c.Request.Context(), user, usecase.TargetTypePost, postID, req.Content)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toCommentResponse(comment))
}

func (h *Handler) ListComments(c *gin.Context) {
	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListComments(c.Request.Context(), usecase.TargetTypePost, postID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]CommentResponse, 0, len(list))
	for _, comment := range list {
		out = append(out, toCommentResponse(comment))
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

func getUserOptional(c *gin.Context) *authdomain.User {
	val, exists := c.Get(string(middleware.UserContextKey))
	if !exists {
		return nil
	}
	user, ok := val.(*authdomain.User)
	if !ok {
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

func toPostResponse(p *socialdomain.Post) PostResponse {
	return PostResponse{
		ID:        p.ID.String(),
		UserID:    p.UserID.String(),
		Content:   p.Content,
		CreatedAt: p.CreatedAt.Format(time.RFC3339),
	}
}

func toCommentResponse(c *socialdomain.Comment) CommentResponse {
	return CommentResponse{
		ID:        c.ID.String(),
		UserID:    c.UserID.String(),
		Content:   c.Content,
		CreatedAt: c.CreatedAt.Format(time.RFC3339),
	}
}
