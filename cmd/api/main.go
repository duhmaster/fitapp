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
	blogdelivery "github.com/fitflow/fitflow/internal/blog/delivery"
	blogrepository "github.com/fitflow/fitflow/internal/blog/repository"
	blogusecase "github.com/fitflow/fitflow/internal/blog/usecase"
	authusecase "github.com/fitflow/fitflow/internal/auth/usecase"
	"github.com/fitflow/fitflow/internal/config"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	httpdelivery "github.com/fitflow/fitflow/internal/delivery/http"
	"github.com/fitflow/fitflow/internal/pkg/logger"
	"github.com/fitflow/fitflow/internal/pkg/postgres"
	"github.com/fitflow/fitflow/internal/pkg/redis"
	"github.com/fitflow/fitflow/internal/pkg/storage"
	gymdelivery "github.com/fitflow/fitflow/internal/gym/delivery"
	gymrepository "github.com/fitflow/fitflow/internal/gym/repository"
	gymusecase "github.com/fitflow/fitflow/internal/gym/usecase"
	progressdelivery "github.com/fitflow/fitflow/internal/progress/delivery"
	progressrepository "github.com/fitflow/fitflow/internal/progress/repository"
	progressusecase "github.com/fitflow/fitflow/internal/progress/usecase"
	socialdelivery "github.com/fitflow/fitflow/internal/social/delivery"
	socialrepository "github.com/fitflow/fitflow/internal/social/repository"
	socialusecase "github.com/fitflow/fitflow/internal/social/usecase"
	notificationdelivery "github.com/fitflow/fitflow/internal/notification/delivery"
	notificationrepository "github.com/fitflow/fitflow/internal/notification/repository"
	notificationusecase "github.com/fitflow/fitflow/internal/notification/usecase"
	trainerdelivery "github.com/fitflow/fitflow/internal/trainer/delivery"
	trainerrepository "github.com/fitflow/fitflow/internal/trainer/repository"
	trainerusecase "github.com/fitflow/fitflow/internal/trainer/usecase"
	userdelivery "github.com/fitflow/fitflow/internal/user/delivery"
	userrepository "github.com/fitflow/fitflow/internal/user/repository"
	userusecase "github.com/fitflow/fitflow/internal/user/usecase"
	workoutdelivery "github.com/fitflow/fitflow/internal/workout/delivery"
	workoutrepository "github.com/fitflow/fitflow/internal/workout/repository"
	workoutusecase "github.com/fitflow/fitflow/internal/workout/usecase"
	"github.com/fitflow/fitflow/internal/workers"
)

func main() {
	if err := run(); err != nil {
		fmt.Fprintf(os.Stderr, "fatal: %v\n", err)
		os.Exit(1)
	}
}

func run() error {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

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

	// Gym module
	gymRepo := gymrepository.NewGymRepository(db)
	checkInRepo := gymrepository.NewCheckInRepository(db)
	snapshotRepo := gymrepository.NewLoadSnapshotRepository(db)
	loadService := gymusecase.NewRedisLoadService(rdb, cfg.GymPresenceWindow)
	gymUC := gymusecase.NewGymUseCase(gymRepo, checkInRepo, snapshotRepo, loadService)
	gymHandler := gymdelivery.NewHandler(gymUC)

	// Workout module
	exerciseRepo := workoutrepository.NewExerciseRepository(db)
	workoutRepo := workoutrepository.NewWorkoutRepository(db)
	workoutExerciseRepo := workoutrepository.NewWorkoutExerciseRepository(db)
	exerciseLogRepo := workoutrepository.NewExerciseLogRepository(db)
	workoutUC := workoutusecase.NewWorkoutUseCase(exerciseRepo, workoutRepo, workoutExerciseRepo, exerciseLogRepo)
	workoutHandler := workoutdelivery.NewHandler(workoutUC)

	// Progress module
	weightRepo := progressrepository.NewWeightTrackingRepository(db)
	bodyFatRepo := progressrepository.NewBodyFatTrackingRepository(db)
	healthMetricRepo := progressrepository.NewHealthMetricRepository(db)
	progressUC := progressusecase.NewProgressUseCase(weightRepo, bodyFatRepo, healthMetricRepo)
	progressHandler := progressdelivery.NewHandler(progressUC)

	// Social module
	followRepo := socialrepository.NewFollowRepository(db)
	friendRequestRepo := socialrepository.NewFriendRequestRepository(db)
	postRepo := socialrepository.NewPostRepository(db)
	likeRepo := socialrepository.NewLikeRepository(db)
	commentRepo := socialrepository.NewCommentRepository(db)
	socialUC := socialusecase.NewSocialUseCase(followRepo, friendRequestRepo, postRepo, likeRepo, commentRepo)
	socialHandler := socialdelivery.NewHandler(socialUC)

	// Blog module
	blogPostRepo := blogrepository.NewBlogPostRepository(db)
	blogPhotoRepo := blogrepository.NewBlogPostPhotoRepository(db)
	tagRepo := blogrepository.NewTagRepository(db)
	blogPostTagRepo := blogrepository.NewBlogPostTagRepository(db)
	blogUC := blogusecase.NewBlogUseCase(blogPostRepo, blogPhotoRepo, tagRepo, blogPostTagRepo)
	blogHandler := blogdelivery.NewHandler(blogUC)

	// Trainer module
	trainerClientRepo := trainerrepository.NewTrainerClientRepository(db)
	trainingProgramRepo := trainerrepository.NewTrainingProgramRepository(db)
	trainerCommentRepo := trainerrepository.NewTrainerCommentRepository(db)
	trainerUC := trainerusecase.NewTrainerUseCase(trainerClientRepo, trainingProgramRepo, trainerCommentRepo)
	trainerHandler := trainerdelivery.NewHandler(trainerUC)

	// Notification module
	notificationRepo := notificationrepository.NewNotificationRepository(db)
	notificationUC := notificationusecase.NewNotificationUseCase(notificationRepo)
	notificationHandler := notificationdelivery.NewHandler(notificationUC)

	// HTTP server
	healthHandler := httpdelivery.NewHealthHandler(db, rdb)
	srv := httpdelivery.New(log)
	srv.RegisterRoutes(&httpdelivery.RoutesConfig{
		AllowedOrigins:  middleware.ParseCORSOrigins(cfg.CORSAllowedOrigins),
		HealthHandler:  healthHandler,
		AuthHandler:    authHandler,
		UserHandler:    userHandler,
		GymHandler:     gymHandler,
		WorkoutHandler:  workoutHandler,
		ProgressHandler: progressHandler,
		SocialHandler:   socialHandler,
		BlogHandler:     blogHandler,
		TrainerHandler:      trainerHandler,
		NotificationHandler: notificationHandler,
		JWTSecret:           []byte(cfg.JWTSecret),
		UploadsPath:    cfg.StoragePath,
	})

	// Background workers (in-process for now; split into separate worker cmd later)
	worker := workers.NewGymLoadSnapshotWorker(log, gymRepo, snapshotRepo, loadService, cfg.GymSnapshotInterval, cfg.GymSnapshotBatchSize)
	go worker.Run(ctx)

	// Start server
	go func() {
		addr := fmt.Sprintf(":%d", cfg.Port)
		if err := srv.Run(addr); err != nil && err != http.ErrServerClosed {
			log.Error().Err(err).Msg("HTTP server error")
		}
	}()

	<-ctx.Done()
	log.Info().Msg("shutdown signal received")

	shutdownCtx, cancel := context.WithTimeout(context.Background(), 30*time.Second)
	defer cancel()

	if err := srv.Shutdown(shutdownCtx); err != nil {
		return fmt.Errorf("http shutdown: %w", err)
	}

	log.Info().Msg("shutdown complete")
	return nil
}
