package delivery

import (
	"net/http"

	"github.com/fitflow/fitflow/internal/photo/usecase"
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

// Handler handles photo HTTP requests.
type Handler struct {
	uc *usecase.PhotoUseCase
}

// NewHandler creates a new photo handler.
func NewHandler(uc *usecase.PhotoUseCase) *Handler {
	return &Handler{uc: uc}
}

// UploadPhotoRequest is multipart form with "file" and optional "bucket".
// UploadPhotoResponse is the JSON response.
type UploadPhotoResponse struct {
	PhotoID string `json:"photo_id"`
	URL     string `json:"url"`
}

// Upload handles multipart file upload. Requires JWT auth.
func (h *Handler) Upload(c *gin.Context) {
	userIDVal, exists := c.Get("user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	userID, ok := userIDVal.(uuid.UUID)
	if !ok {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "invalid user_id"})
		return
	}

	file, err := c.FormFile("file")
	if err != nil || file == nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "file required"})
		return
	}
	bucket := c.PostForm("bucket")
	if bucket == "" {
		bucket = "gymmore"
	}
	f, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	defer f.Close()

	res, err := h.uc.Upload(c.Request.Context(), bucket, "group-trainings", f, file.Header.Get("Content-Type"), &userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": err.Error()})
		return
	}
	c.JSON(http.StatusOK, UploadPhotoResponse{PhotoID: res.PhotoID.String(), URL: res.URL})
}
