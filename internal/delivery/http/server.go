package http

import (
	"context"
	"fmt"
	"net/http"
	"time"

	"github.com/fitflow/fitflow/internal/delivery/middleware"
	"github.com/gin-gonic/gin"
	"github.com/rs/zerolog"
)

// Server wraps the HTTP server and router.
type Server struct {
	router *gin.Engine
	http   *http.Server
	log    zerolog.Logger
}

// New creates an HTTP server with middleware and routes.
func New(log zerolog.Logger) *Server {
	gin.SetMode(gin.ReleaseMode)
	router := gin.New()

	// Global middleware (RequestID first so logs can include it)
	router.Use(Recovery(log))
	router.Use(middleware.RequestID())
	router.Use(RequestLogger(log))

	return &Server{
		router: router,
		log:    log,
	}
}


// Run starts the HTTP server and blocks until shutdown.
func (s *Server) Run(addr string) error {
	s.http = &http.Server{
		Addr:         addr,
		Handler:      s.router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	s.log.Info().Str("addr", addr).Msg("HTTP server starting")
	if err := s.http.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		return fmt.Errorf("http listen: %w", err)
	}
	return nil
}

// Shutdown gracefully stops the server with the given timeout.
func (s *Server) Shutdown(ctx context.Context) error {
	s.log.Info().Msg("HTTP server shutting down")
	if s.http == nil {
		return nil
	}
	return s.http.Shutdown(ctx)
}
