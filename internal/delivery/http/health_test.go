package http

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/fitflow/fitflow/internal/pkg/version"
	"github.com/gin-gonic/gin"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
)

func TestHealthHandler_Health(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewHealthHandler((*pgxpool.Pool)(nil), (*redis.Client)(nil))

	router := gin.New()
	router.GET("/health", h.Health)

	req := httptest.NewRequest(http.MethodGet, "/health", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("Health: got status %d, want 200", rec.Code)
	}
	if rec.Header().Get("Content-Type") != "application/json; charset=utf-8" {
		t.Errorf("Health: Content-Type = %q", rec.Header().Get("Content-Type"))
	}
}

func TestHealthHandler_Live(t *testing.T) {
	gin.SetMode(gin.TestMode)
	h := NewHealthHandler((*pgxpool.Pool)(nil), (*redis.Client)(nil))

	router := gin.New()
	router.GET("/health/live", h.Live)

	req := httptest.NewRequest(http.MethodGet, "/health/live", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("Live: got status %d, want 200", rec.Code)
	}
}

func TestVersionRoute(t *testing.T) {
	gin.SetMode(gin.TestMode)
	router := gin.New()
	router.GET("/version", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"version": version.Version})
	})

	req := httptest.NewRequest(http.MethodGet, "/version", nil)
	rec := httptest.NewRecorder()
	router.ServeHTTP(rec, req)

	if rec.Code != http.StatusOK {
		t.Errorf("Version: got status %d, want 200", rec.Code)
		return
	}
	var out struct {
		Version string `json:"version"`
	}
	if err := json.NewDecoder(rec.Body).Decode(&out); err != nil {
		t.Errorf("Version: invalid JSON: %v", err)
		return
	}
	if out.Version == "" {
		t.Error("Version: response version is empty")
	}
}
