package delivery

import (
	"net/http"

	"github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	"github.com/fitflow/fitflow/internal/auth/usecase"
	"github.com/gin-gonic/gin"
)

// Handler handles auth HTTP requests.
type Handler struct {
	uc *usecase.AuthUseCase
}

// NewHandler creates a new auth Handler.
func NewHandler(uc *usecase.AuthUseCase) *Handler {
	return &Handler{uc: uc}
}

// RegisterRequest is the JSON body for registration.
type RegisterRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required,min=8"`
	Role     string `json:"role"`
}

// RegisterResponse is the JSON response for auth endpoints.
type RegisterResponse struct {
	User         UserResponse `json:"user"`
	AccessToken  string       `json:"access_token"`
	RefreshToken string       `json:"refresh_token"`
	ExpiresIn    int64        `json:"expires_in"`
}

// UserResponse is the user in auth responses.
type UserResponse struct {
	ID    string `json:"id"`
	Email string `json:"email"`
	Role  string `json:"role"`
}

// LoginRequest is the JSON body for login.
type LoginRequest struct {
	Email    string `json:"email" binding:"required,email"`
	Password string `json:"password" binding:"required"`
}

// RefreshRequest is the JSON body for token refresh.
type RefreshRequest struct {
	RefreshToken string `json:"refresh_token" binding:"required"`
}

// Register godoc
// @Summary  Register a new user
// @Tags     auth
// @Accept   json
// @Produce  json
// @Param    body body RegisterRequest true "Registration data"
// @Success  201 {object} RegisterResponse
// @Failure  400 {object} map[string]string
// @Failure  409 {object} map[string]string
// @Router   /auth/register [post]
func (h *Handler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	role := domain.RoleUser
	if req.Role != "" {
		role = domain.Role(req.Role)
		if role != domain.RoleUser && role != domain.RoleTrainer && role != domain.RoleAdmin {
			c.JSON(http.StatusBadRequest, gin.H{"error": "invalid role"})
			return
		}
	}

	out, err := h.uc.Register(c.Request.Context(), usecase.RegisterInput{
		Email:    req.Email,
		Password: req.Password,
		Role:     role,
	})
	if err != nil {
		switch err {
		case domain.ErrUserAlreadyExists:
			c.JSON(http.StatusConflict, gin.H{"error": "user with this email already exists"})
			return
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "registration failed"})
			return
		}
	}

	c.JSON(http.StatusCreated, RegisterResponse{
		User:         toUserResponse(out.User),
		AccessToken:  out.AccessToken,
		RefreshToken: out.RefreshToken,
		ExpiresIn:    out.ExpiresIn,
	})
}

// Login godoc
// @Summary  Login
// @Tags     auth
// @Accept   json
// @Produce  json
// @Param    body body LoginRequest true "Credentials"
// @Success  200 {object} RegisterResponse
// @Failure  400 {object} map[string]string
// @Failure  401 {object} map[string]string
// @Router   /auth/login [post]
func (h *Handler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	out, err := h.uc.Login(c.Request.Context(), usecase.LoginInput{
		Email:    req.Email,
		Password: req.Password,
	})
	if err != nil {
		switch err {
		case domain.ErrUserNotFound, domain.ErrInvalidPassword:
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid email or password"})
			return
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "login failed"})
			return
		}
	}

	c.JSON(http.StatusOK, RegisterResponse{
		User:         toUserResponse(out.User),
		AccessToken:  out.AccessToken,
		RefreshToken: out.RefreshToken,
		ExpiresIn:    out.ExpiresIn,
	})
}

// Refresh godoc
// @Summary  Refresh tokens
// @Tags     auth
// @Accept   json
// @Produce  json
// @Param    body body RefreshRequest true "Refresh token"
// @Success  200 {object} map[string]interface{}
// @Failure  400 {object} map[string]string
// @Failure  401 {object} map[string]string
// @Router   /auth/refresh [post]
func (h *Handler) Refresh(c *gin.Context) {
	var req RefreshRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	out, err := h.uc.Refresh(c.Request.Context(), usecase.RefreshInput{
		RefreshToken: req.RefreshToken,
	})
	if err != nil {
		switch err {
		case domain.ErrInvalidToken:
			c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired refresh token"})
			return
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "refresh failed"})
			return
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"access_token":  out.AccessToken,
		"refresh_token": out.RefreshToken,
		"expires_in":    out.ExpiresIn,
	})
}

func toUserResponse(u *domain.User) UserResponse {
	return UserResponse{
		ID:    u.ID.String(),
		Email: u.Email,
		Role:  string(u.Role),
	}
}

// Me returns the current authenticated user. Requires JWTAuth middleware.
func (h *Handler) Me(c *gin.Context) {
	val, exists := c.Get(string(middleware.UserContextKey))
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
		return
	}
	user, ok := val.(*domain.User)
	if !ok {
		c.JSON(http.StatusForbidden, gin.H{"error": "forbidden"})
		return
	}
	c.JSON(http.StatusOK, toUserResponse(user))
}
