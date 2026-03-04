package delivery

import (
	"net/http"
	"strconv"
	"time"

	authdomain "github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	blogdomain "github.com/fitflow/fitflow/internal/blog/domain"
	"github.com/fitflow/fitflow/internal/blog/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

type Handler struct {
	uc *usecase.BlogUseCase
}

func NewHandler(uc *usecase.BlogUseCase) *Handler {
	return &Handler{uc: uc}
}

type BlogPostResponse struct {
	ID        string   `json:"id"`
	UserID    string   `json:"user_id"`
	Title     string   `json:"title"`
	Content   *string  `json:"content,omitempty"`
	CreatedAt string   `json:"created_at"`
	UpdatedAt string   `json:"updated_at"`
}

type BlogPostPhotoResponse struct {
	ID        string `json:"id"`
	PostID    string `json:"post_id"`
	URL       string `json:"url"`
	SortOrder int    `json:"sort_order"`
}

type TagResponse struct {
	ID   string `json:"id"`
	Name string `json:"name"`
}

type CreatePostRequest struct {
	Title   string  `json:"title" binding:"required"`
	Content *string `json:"content"`
}

type UpdatePostRequest struct {
	Title   string  `json:"title"`
	Content *string `json:"content"`
}

type AddPhotoRequest struct {
	URL       string `json:"url" binding:"required"`
	SortOrder *int   `json:"sort_order"`
}

type CreateTagRequest struct {
	Name string `json:"name" binding:"required"`
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

	p, err := h.uc.CreatePost(c.Request.Context(), user, req.Title, req.Content)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toBlogPostResponse(p))
}

func (h *Handler) GetPost(c *gin.Context) {
	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	p, err := h.uc.GetPost(c.Request.Context(), postID)
	if err != nil {
		if err == blogdomain.ErrBlogPostNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	if p.DeletedAt != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "post not found"})
		return
	}

	photos, _ := h.uc.ListPhotos(c.Request.Context(), postID)
	tagIDs, _ := h.uc.GetPostTags(c.Request.Context(), postID)

	photoResp := make([]BlogPostPhotoResponse, 0, len(photos))
	for _, ph := range photos {
		photoResp = append(photoResp, toPhotoResponse(ph))
	}

	tagIDStrs := make([]string, 0, len(tagIDs))
	for _, id := range tagIDs {
		tagIDStrs = append(tagIDStrs, id.String())
	}

	c.JSON(http.StatusOK, gin.H{
		"post":   toBlogPostResponse(p),
		"photos": photoResp,
		"tags":   tagIDStrs,
	})
}

func (h *Handler) UpdatePost(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	var req UpdatePostRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	p, err := h.uc.UpdatePost(c.Request.Context(), user, postID, req.Title, req.Content)
	if err != nil {
		if err == blogdomain.ErrBlogPostNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, toBlogPostResponse(p))
}

func (h *Handler) DeletePost(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	err := h.uc.DeletePost(c.Request.Context(), user, postID)
	if err != nil {
		if err == blogdomain.ErrBlogPostNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) ListMyPosts(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListMyPosts(c.Request.Context(), user, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]BlogPostResponse, 0, len(list))
	for _, p := range list {
		out = append(out, toBlogPostResponse(p))
	}
	c.JSON(http.StatusOK, gin.H{"posts": out})
}

func (h *Handler) ListPosts(c *gin.Context) {
	var tagID *uuid.UUID
	if s := c.Query("tag_id"); s != "" {
		id, err := uuid.Parse(s)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid tag_id"})
			return
		}
		tagID = &id
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "20"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListPosts(c.Request.Context(), tagID, limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]BlogPostResponse, 0, len(list))
	for _, p := range list {
		out = append(out, toBlogPostResponse(p))
	}
	c.JSON(http.StatusOK, gin.H{"posts": out})
}

func (h *Handler) AddPhoto(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	var req AddPhotoRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	sortOrder := 0
	if req.SortOrder != nil {
		sortOrder = *req.SortOrder
	}

	ph, err := h.uc.AddPhoto(c.Request.Context(), user, postID, req.URL, sortOrder)
	if err != nil {
		if err == blogdomain.ErrBlogPostNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toPhotoResponse(ph))
}

func (h *Handler) DeletePhoto(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	photoID, ok := parseUUIDParam(c, "photo_id")
	if !ok {
		return
	}

	err := h.uc.DeletePhoto(c.Request.Context(), user, photoID)
	if err != nil {
		if err == blogdomain.ErrBlogPostNotFound || err == blogdomain.ErrBlogPostPhotoNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) CreateTag(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	var req CreateTagRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	t, err := h.uc.CreateTag(c.Request.Context(), req.Name)
	if err != nil {
		if err == blogdomain.ErrTagExists {
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusCreated, toTagResponse(t))
}

func (h *Handler) ListTags(c *gin.Context) {
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "100"))
	offset, _ := strconv.Atoi(c.DefaultQuery("offset", "0"))

	list, err := h.uc.ListTags(c.Request.Context(), limit, offset)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}

	out := make([]TagResponse, 0, len(list))
	for _, t := range list {
		out = append(out, toTagResponse(t))
	}
	c.JSON(http.StatusOK, gin.H{"tags": out})
}

func (h *Handler) AddTagToPost(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	tagID, ok := parseUUIDParam(c, "tag_id")
	if !ok {
		return
	}

	err := h.uc.AddTagToPost(c.Request.Context(), user, postID, tagID)
	if err != nil {
		if err == blogdomain.ErrBlogPostNotFound || err == blogdomain.ErrTagNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
}

func (h *Handler) RemoveTagFromPost(c *gin.Context) {
	user := getUser(c)
	if user == nil {
		return
	}

	postID, ok := parseUUIDParam(c, "post_id")
	if !ok {
		return
	}

	tagID, ok := parseUUIDParam(c, "tag_id")
	if !ok {
		return
	}

	err := h.uc.RemoveTagFromPost(c.Request.Context(), user, postID, tagID)
	if err != nil {
		if err == blogdomain.ErrBlogPostNotFound {
			c.JSON(http.StatusNotFound, gin.H{"error": err.Error()})
			return
		}
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.Status(http.StatusNoContent)
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

func toBlogPostResponse(p *blogdomain.BlogPost) BlogPostResponse {
	return BlogPostResponse{
		ID:        p.ID.String(),
		UserID:    p.UserID.String(),
		Title:     p.Title,
		Content:   p.Content,
		CreatedAt: p.CreatedAt.Format(time.RFC3339),
		UpdatedAt: p.UpdatedAt.Format(time.RFC3339),
	}
}

func toPhotoResponse(ph *blogdomain.BlogPostPhoto) BlogPostPhotoResponse {
	return BlogPostPhotoResponse{
		ID:        ph.ID.String(),
		PostID:    ph.PostID.String(),
		URL:       ph.URL,
		SortOrder: ph.SortOrder,
	}
}

func toTagResponse(t *blogdomain.Tag) TagResponse {
	return TagResponse{
		ID:   t.ID.String(),
		Name: t.Name,
	}
}
