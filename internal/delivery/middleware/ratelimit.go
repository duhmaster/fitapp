package middleware

import (
	"net/http"
	"sync"
	"time"

	"github.com/gin-gonic/gin"
)

// RateLimit returns a middleware that limits requests per IP using a fixed window.
// window is the duration of each window; limit is the max requests per window per IP.
func RateLimit(limit int, window time.Duration) gin.HandlerFunc {
	type bucket struct {
		count int
		start time.Time
	}
	var (
		mu   sync.Mutex
		ips  = make(map[string]*bucket)
	)

	return func(c *gin.Context) {
		ip := c.ClientIP()
		if ip == "" {
			ip = c.RemoteIP()
		}

		mu.Lock()
		b, ok := ips[ip]
		now := time.Now()
		if !ok || now.Sub(b.start) >= window {
			b = &bucket{count: 1, start: now}
			ips[ip] = b
		} else {
			b.count++
		}
		n := b.count
		mu.Unlock()

		if n > limit {
			c.AbortWithStatusJSON(http.StatusTooManyRequests, gin.H{"error": "rate limit exceeded"})
			return
		}

		c.Next()
	}
}
