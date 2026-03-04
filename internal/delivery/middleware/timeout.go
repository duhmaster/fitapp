package middleware

import (
	"context"
	"time"

	"github.com/gin-gonic/gin"
)

// Timeout returns a middleware that sets a deadline on the request context.
// Handlers that use c.Request.Context() will see context.DeadlineExceeded when the timeout is reached.
// The server's WriteTimeout still applies for the full response.
func Timeout(d time.Duration) gin.HandlerFunc {
	return func(c *gin.Context) {
		ctx, cancel := context.WithTimeout(c.Request.Context(), d)
		defer cancel()
		c.Request = c.Request.WithContext(ctx)
		c.Next()
	}
}
