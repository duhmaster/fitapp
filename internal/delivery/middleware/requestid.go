package middleware

import (
	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
)

const (
	// RequestIDHeader is the header name for the request ID (in and out).
	RequestIDHeader = "X-Request-Id"
	// RequestIDContextKey is the context key for the request ID.
	RequestIDContextKey ContextKey = "request_id"
)

// RequestID returns a middleware that sets a request ID from header or generates one.
// The ID is set in context under RequestIDContextKey and sent back in X-Request-Id.
func RequestID() gin.HandlerFunc {
	return func(c *gin.Context) {
		id := c.GetHeader(RequestIDHeader)
		if id == "" {
			id = uuid.New().String()
		}
		c.Set(string(RequestIDContextKey), id)
		c.Header(RequestIDHeader, id)
		c.Next()
	}
}
