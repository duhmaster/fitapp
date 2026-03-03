// FITFLOW API Server
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	authdelivery "github.com/fitflow/fitflow/internal/auth/delivery"
	authrepository "github.com/fitflow/fitflow/internal/auth/repository"
	authusecase "github.com/fitflow/fitflow/internal/auth/usecase"
	"github.com/fitflow/fitflow/internal/config"
	httpdelivery "github.com/fitflow/fitflow/internal/delivery/http"
	"github.com/fitflow/fitflow/internal/pkg/logger"
	"github.com/fitflow/fitflow/internal/pkg/postgres"
	"github.com/fitflow/fitflow/internal/pkg/redis"
	"github.com/fitflow/fitflow/internal/pkg/storage"
	userdelivery "github.com/fitflow/fitflow/internal/user/delivery"
	userrepository "github.com/fitflow/fitflow/internal/user/repository"
	userusecase "github.com/fitflow/fitflow/internal/user/usecase"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "fatal: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	ctx := context.Background()

	cfg, err := config.Load()
	if err != nil {
		return fmt.Errorf("load config: %w", err)
	}

	log := logger.New(cfg.Env)
	logger.SetGlobal(log)

	// Database
	db, err := postgres.NewPool(ctx, cfg.DSN())
	if err != nil {
		return fmt.Errorf("connect db: %w", err)
	}
	defer db.Close()

	// Redis
	rdb := redis.NewClient(cfg.RedisAddr, cfg.RedisPassword, cfg.RedisDB)
	defer rdb.Close()

	if err := redis.Ping(ctx, rdb); err != nil {
		return fmt.Errorf("connect redis: %w", err)
	}

	// Auth module
	authUserRepo := authrepository.NewUserRepository(db)
	refreshTokenRepo := authrepository.NewRefreshTokenRepository(db)
	authUC := authusecase.NewAuthUseCase(
		authUserRepo,
		refreshTokenRepo,
		[]byte(cfg.JWTSecret),
		cfg.JWTAccessExpiry,
		cfg.JWTRefreshExpiry,
	)
	authHandler := authdelivery.NewHandler(authUC)

	// Storage (filesystem for avatars)
	var store storage.Store
	if cfg.StoragePath != "" {
		store = storage.NewFilesystemStore(cfg.StoragePath, cfg.StorageBaseURL)
	}

	// User module
	profileRepo := userrepository.NewProfileRepository(db)
	metricRepo := userrepository.NewMetricRepository(db)
	userUC := userusecase.NewUserUseCase(profileRepo, metricRepo, store)
	userHandler := userdelivery.NewHandler(userUC)

	// HTTP server
	healthHandler := httpdelivery.NewHealthHandler(db, rdb)
	srv := httpdelivery.New(log)
	srv.RegisterRoutes(&httpdelivery.RoutesConfig{
		HealthHandler: healthHandler,
		AuthHandler:   authHandler,
		UserHandler:   userHandler,
		JWTSecret:     []byte(cfg.JWTSecret),
		UploadsPath:   cfg.StoragePath,
	})

	// Graceful shutdown
	go func() {
		addr := fmt.Sprintf(":%d", cfg.Port)
		if err := srv.Run(addr); err != nil && err != http.ErrServerClosed {
			log.Error().Err(err).Msg("HTTP server error")
		}
	}()

	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	log.Info().Msg("shutdown signal received")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("http shutdown: %w", err)
	}

	log.Info().Msg("shutdown complete")
	return nil
}
