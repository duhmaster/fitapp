// GymMore API Server (gymmore.ru)
package main

import (
	"context"
	"fmt"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/fitflow/fitflow/internal/admin"
	authdelivery "github.com/fitflow/fitflow/internal/auth/delivery"
	authrepository "github.com/fitflow/fitflow/internal/auth/repository"
	blogdelivery "github.com/fitflow/fitflow/internal/blog/delivery"
	blogrepository "github.com/fitflow/fitflow/internal/blog/repository"
	blogusecase "github.com/fitflow/fitflow/internal/blog/usecase"
	authusecase "github.com/fitflow/fitflow/internal/auth/usecase"
	"github.com/fitflow/fitflow/internal/config"
	"github.com/fitflow/fitflow/internal/geo"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	httpdelivery "github.com/fitflow/fitflow/internal/delivery/http"
	"github.com/fitflow/fitflow/internal/pkg/logger"
	"github.com/fitflow/fitflow/internal/pkg/postgres"
	"github.com/fitflow/fitflow/internal/pkg/redis"
	"github.com/fitflow/fitflow/internal/pkg/storage"
	gymdomain "github.com/fitflow/fitflow/internal/gym/domain"
	gymdelivery "github.com/fitflow/fitflow/internal/gym/delivery"
	gymrepository "github.com/fitflow/fitflow/internal/gym/repository"
	gymusecase "github.com/fitflow/fitflow/internal/gym/usecase"
	"github.com/google/uuid"
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
	bodyMeasurementRepo := userrepository.NewBodyMeasurementRepository(db)
	userUC := userusecase.NewUserUseCase(profileRepo, metricRepo, bodyMeasurementRepo, store)
	userHandler := userdelivery.NewHandler(userUC)

	// Gym module
	gymRepo := gymrepository.NewGymRepository(db)
	userGymRepo := gymrepository.NewUserGymRepository(db)
	checkInRepo := gymrepository.NewCheckInRepository(db)
	snapshotRepo := gymrepository.NewLoadSnapshotRepository(db)
	loadService := gymusecase.NewRedisLoadService(rdb, cfg.GymPresenceWindow)
	gymUC := gymusecase.NewGymUseCase(gymRepo, userGymRepo, checkInRepo, snapshotRepo, loadService)
	gymHandler := gymdelivery.NewHandler(gymUC)

	// Workout module
	exerciseRepo := workoutrepository.NewExerciseRepository(db)
	workoutRepo := workoutrepository.NewWorkoutRepository(db)
	workoutExerciseRepo := workoutrepository.NewWorkoutExerciseRepository(db)
	exerciseLogRepo := workoutrepository.NewExerciseLogRepository(db)
	programRepo := workoutrepository.NewProgramRepository(db)
	programExerciseRepo := workoutrepository.NewProgramExerciseRepository(db)
	templateRepo := workoutrepository.NewWorkoutTemplateRepository(db)
	templateExerciseRepo := workoutrepository.NewWorkoutTemplateExerciseRepository(db)
	templateSetRepo := workoutrepository.NewTemplateExerciseSetRepository(db)
	workoutUC := workoutusecase.NewWorkoutUseCase(exerciseRepo, workoutRepo, workoutExerciseRepo, exerciseLogRepo, programRepo, programExerciseRepo, templateRepo, templateExerciseRepo, templateSetRepo)
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

	// Admin panel (only if credentials set)
	var adminHandler *admin.Handler
	if cfg.AdminPassword != "" {
		adminDeps := &admin.Deps{
			AdminUsername:  cfg.AdminUsername,
			AdminPassword:  cfg.AdminPassword,
			SessionSecret:  cfg.AdminPassword,
			UsersList:      authUserRepo.List,
			UsersGet:       authUserRepo.GetByID,
			UsersUpdateRole: authUserRepo.UpdateRole,
			GymsSearch:     func(ctx context.Context, q, city string, lat, lng *float64, limit, offset int) ([]*gymdomain.Gym, error) {
				return gymRepo.Search(ctx, q, city, lat, lng, limit, offset)
			},
			GymsCreate:     func(ctx context.Context, name string, lat, lng *float64, address string) (*gymdomain.Gym, error) {
				return gymRepo.Create(ctx, name, "", address, "", "", lat, lng)
			},
			GymsGet:    gymRepo.GetByID,
			GymsUpdate: func(ctx context.Context, id uuid.UUID, name string, lat, lng *float64, address string) (*gymdomain.Gym, error) {
				return gymRepo.Update(ctx, id, name, "", address, "", "", lat, lng)
			},
			GymsDelete: gymRepo.SoftDelete,
			ExercisesList:   exerciseRepo.List,
			ExercisesGet:   exerciseRepo.GetByID,
			ExercisesCreate: exerciseRepo.Create,
			ExercisesUpdate: exerciseRepo.Update,
			ExercisesDelete: exerciseRepo.Delete,
			ProgramsList:   programRepo.List,
			ProgramsGet:    programRepo.GetByID,
			ProgramsCreate: programRepo.Create,
			ProgramsUpdate: programRepo.Update,
			ProgramsDelete: programRepo.Delete,
			TagsList:       tagRepo.List,
			TagsGet:        tagRepo.GetByID,
			TagsCreate:     tagRepo.Create,
			TagsDelete:     tagRepo.Delete,
			BlogPostsList:   blogPostRepo.List,
			BlogPostsGet:   blogPostRepo.GetByID,
			BlogPostsCreate: blogPostRepo.Create,
			BlogPostsUpdate: blogPostRepo.Update,
			BlogPostsDelete: blogPostRepo.SoftDelete,
		}
		adminHandler = admin.NewHandler(adminDeps)
	}

	// HTTP server
	healthHandler := httpdelivery.NewHealthHandler(db, rdb)
	srv := httpdelivery.New(log)
	srv.RegisterRoutes(&httpdelivery.RoutesConfig{
		AllowedOrigins:     middleware.ParseCORSOrigins(cfg.CORSAllowedOrigins),
		HealthHandler:     healthHandler,
		AuthHandler:       authHandler,
		UserHandler:       userHandler,
		GeoClient:         geo.NewClient(cfg.DADATAAPIKey, cfg.DADATASecretKey),
		GymHandler:        gymHandler,
		WorkoutHandler:    workoutHandler,
		ProgressHandler:   progressHandler,
		SocialHandler:     socialHandler,
		BlogHandler:       blogHandler,
		TrainerHandler:    trainerHandler,
		NotificationHandler: notificationHandler,
		AdminHandler:      adminHandler,
		JWTSecret:         []byte(cfg.JWTSecret),
		UploadsPath:       cfg.StoragePath,
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
