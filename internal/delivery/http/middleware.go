package http

import (
	"time"

	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog"
)

// Recovery returns a Gin middleware that recovers from panics and logs them.
func Recovery(log zerolog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		defer func() {
			if err := recover(); err != nil {
				log.Error().
					Interface("panic", err).
					Str("path", c.Request.URL.Path).
					Str("method", c.Request.Method).
					Msg("panic recovered")
				c.AbortWithStatus(500)
			}
		}()
		c.Next()
	}
}

// RequestLogger logs each request with method, path, status, and duration.
func RequestLogger(log zerolog.Logger) gin.HandlerFunc {
	return func(c *gin.Context) {
		start := time.Now()
		path := c.Request.URL.Path
		method := c.Request.Method
		clientIP := c.ClientIP()

		c.Next()

		latency := time.Since(start)
		status := c.Writer.Status()

		log.Info().
			Str("method", method).
			Str("path", path).
			Str("client_ip", clientIP).
			Int("status", status).
			Dur("latency", latency).
			Msg("request")
	}
}
