package middleware

import (
	"net/http"
	"strings"

	"github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/auth/usecase"
	"github.com/gin-gonic/gin"
)

// ContextKey type for gin context keys.
type ContextKey string

const (
	// UserContextKey is the key for the authenticated user in context.
	UserContextKey ContextKey = "user"
)

// JWTAuth returns a middleware that validates JWT and sets user in context.
func JWTAuth(jwtSecret []byte) gin.HandlerFunc {
	return func(c *gin.Context) {
		auth := c.GetHeader("Authorization")
		if auth == "" {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing authorization header"})
			return
		}

		parts := strings.SplitN(auth, " ", 2)
		if len(parts) != 2 || !strings.EqualFold(parts[0], "Bearer") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid authorization header"})
			return
		}

		user, err := usecase.ValidateAccessToken(parts[1], jwtSecret)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid or expired token"})
			return
		}

		c.Set(string(UserContextKey), user)
		c.Next()
	}
}

// RequireRole returns a middleware that restricts access to given roles.
// Must be used after JWTAuth.
func RequireRole(roles ...domain.Role) gin.HandlerFunc {
	allowed := make(map[domain.Role]struct{})
	for _, r := range roles {
		allowed[r] = struct{}{}
	}

	return func(c *gin.Context) {
		val, exists := c.Get(string(UserContextKey))
		if !exists {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "unauthorized"})
			return
		}

		user, ok := val.(*domain.User)
		if !ok {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "forbidden"})
			return
		}

		if _, ok := allowed[user.Role]; !ok {
			c.AbortWithStatusJSON(http.StatusForbidden, gin.H{"error": "insufficient permissions"})
			return
		}

		c.Next()
	}
}
