// GymMore API Server (gymmore.ru)
package main

import (
	"context"
	"fmt"
	"io"
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
	grouptrainingdelivery "github.com/fitflow/fitflow/internal/grouptraining/delivery"
	grouptrainingrepository "github.com/fitflow/fitflow/internal/grouptraining/repository"
	grouptrainingusecase "github.com/fitflow/fitflow/internal/grouptraining/usecase"
	photodelivery "github.com/fitflow/fitflow/internal/photo/delivery"
	photorepository "github.com/fitflow/fitflow/internal/photo/repository"
	photousecase "github.com/fitflow/fitflow/internal/photo/usecase"
	systemmessagedomain "github.com/fitflow/fitflow/internal/systemmessage/domain"
	systemmessagedelivery "github.com/fitflow/fitflow/internal/systemmessage/delivery"
	systemmessagerepository "github.com/fitflow/fitflow/internal/systemmessage/repository"
	systemmessageusecase "github.com/fitflow/fitflow/internal/systemmessage/usecase"
	trainerdelivery "github.com/fitflow/fitflow/internal/trainer/delivery"
	trainerrepository "github.com/fitflow/fitflow/internal/trainer/repository"
	trainerusecase "github.com/fitflow/fitflow/internal/trainer/usecase"
	userdelivery "github.com/fitflow/fitflow/internal/user/delivery"
	userrepository "github.com/fitflow/fitflow/internal/user/repository"
	userusecase "github.com/fitflow/fitflow/internal/user/usecase"
	workoutdelivery "github.com/fitflow/fitflow/internal/workout/delivery"
	workoutrepository "github.com/fitflow/fitflow/internal/workout/repository"
	workoutusecase "github.com/fitflow/fitflow/internal/workout/usecase"
	gamificationdelivery "github.com/fitflow/fitflow/internal/gamification/delivery"
	gamificationrepository "github.com/fitflow/fitflow/internal/gamification/repository"
	gamificationusecase "github.com/fitflow/fitflow/internal/gamification/usecase"
	"github.com/fitflow/fitflow/internal/workers"
	gamleaderboard "github.com/fitflow/fitflow/internal/gamification/leaderboard"
	"github.com/jackc/pgx/v5"
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
		nil,
	)
	authHandler := authdelivery.NewHandler(authUC)

	// Storage (filesystem for avatars)
	var store storage.Store
	if cfg.StoragePath != "" {
		store = storage.NewFilesystemStore(cfg.StoragePath, cfg.StorageBaseURL)
	}

	// S3 store (for production photo uploads)
	var s3Store *storage.S3Store
	if cfg.S3Endpoint != "" && cfg.S3AccessKey != "" && cfg.S3SecretKey != "" {
		s3, err := storage.NewS3Store(storage.S3Config{
			Endpoint:  cfg.S3Endpoint,
			AccessKey: cfg.S3AccessKey,
			SecretKey: cfg.S3SecretKey,
			Bucket:    cfg.S3Bucket,
			Region:    cfg.S3Region,
			PublicURL: cfg.S3PublicURL,
			UseSSL:    cfg.S3UseSSL,
		})
		if err != nil {
			return fmt.Errorf("s3 store: %w", err)
		}
		s3Store = s3
	}

	// Photo module
	bucketRepo := photorepository.NewBucketRepository(db)
	photoRepo := photorepository.NewPhotoRepository(db)
	photoUC := photousecase.NewPhotoUseCase(photoRepo, bucketRepo, s3Store, store)

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

	gamLB := gamleaderboard.New(rdb)
	gamRepo := gamificationrepository.NewPG(db, gamLB)
	gamUC := gamificationusecase.New(gamRepo, gamLB)
	gymUC.SetGamificationOnCheckIn(func(ctx context.Context, userID, gymID uuid.UUID) error {
		return gamUC.ApplyGymCheckInMission(ctx, userID, gymID)
	})
	userUC.SetGamificationOnBodyMeasurement(func(ctx context.Context, userID, measurementID uuid.UUID) error {
		return gamUC.ApplyBodyMeasurementReward(ctx, userID, measurementID)
	})

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
	workoutUC.SetGamificationOutbox(db, func(ctx context.Context, tx pgx.Tx, userID, workoutID uuid.UUID, volumeKg float64) error {
		return gamRepo.EnqueueWorkoutFinished(ctx, tx, userID, workoutID, volumeKg)
	}, func(ctx context.Context) error {
		_, err := gamRepo.ProcessOutbox(ctx, 50)
		return err
	})
	workoutHandler := workoutdelivery.NewHandler(workoutUC)
	gamificationHandler := gamificationdelivery.NewHandler(gamUC)
	gamificationAdminHandler := gamificationdelivery.NewAdminHandler(gamRepo)

	// Default workout templates for newly registered users
	authUC.SetDefaultTemplatesDeps(&authusecase.DefaultTemplatesDeps{
		Exercises:         exerciseRepo,
		Templates:         templateRepo,
		TemplateExercises: templateExerciseRepo,
		TemplateSets:      templateSetRepo,
	})

	// Progress module
	weightRepo := progressrepository.NewWeightTrackingRepository(db)
	bodyFatRepo := progressrepository.NewBodyFatTrackingRepository(db)
	healthMetricRepo := progressrepository.NewHealthMetricRepository(db)
	progressUC := progressusecase.NewProgressUseCase(weightRepo, bodyFatRepo, healthMetricRepo)
	progressHandler := progressdelivery.NewHandler(progressUC)

	// Group training module
	groupTypeRepo := grouptrainingrepository.NewGroupTrainingTypeRepository(db)
	groupTemplateRepo := grouptrainingrepository.NewGroupTrainingTemplateRepository(db)
	groupTrainingRepo := grouptrainingrepository.NewGroupTrainingRepository(db)
	groupRegistrationRepo := grouptrainingrepository.NewGroupTrainingRegistrationRepository(db)
	groupTrainingUC := grouptrainingusecase.NewGroupTrainingUseCase(groupTypeRepo, groupTemplateRepo, groupTrainingRepo, groupRegistrationRepo, authUserRepo)
	groupTrainingUC.SetGamificationOnRegister(func(ctx context.Context, userID, trainingID uuid.UUID) error {
		return gamUC.ApplyGroupTrainingRegistrationReward(ctx, userID, trainingID)
	})
	groupTrainingHandler := grouptrainingdelivery.NewHandler(groupTrainingUC)

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
	trainerProfileRepo := trainerrepository.NewTrainerProfileRepository(db)
	trainerPhotoRepo := trainerrepository.NewTrainerPhotoRepository(db)
	trainerUC := trainerusecase.NewTrainerUseCase(trainerClientRepo, trainingProgramRepo, trainerCommentRepo, trainerProfileRepo, trainerPhotoRepo, userGymRepo)
	workoutUC.SetTrainerChecker(trainerUC)
	trainerHandler := trainerdelivery.NewHandler(trainerUC)
	trainerHandler.SetProfileResolver(func(ctx context.Context, userID uuid.UUID) (displayName, city, avatarURL string) {
		p, err := profileRepo.GetByUserID(ctx, userID)
		if err != nil || p == nil {
			return "", "", ""
		}
		return p.DisplayName, p.City, p.AvatarURL
	})
	trainerHandler.SetPublicProfileDeps(
		func(ctx context.Context, trainerID uuid.UUID) (int, error) { return workoutUC.CountByTrainerID(ctx, trainerID) },
		func(ctx context.Context, userID uuid.UUID) ([]trainerdelivery.PublicProfileGym, error) {
			gyms, err := gymUC.ListGymsByUserID(ctx, userID)
			if err != nil {
				return nil, err
			}
			out := make([]trainerdelivery.PublicProfileGym, 0, len(gyms))
			for _, g := range gyms {
				out = append(out, trainerdelivery.PublicProfileGym{ID: g.ID.String(), Name: g.Name, City: g.City})
			}
			return out, nil
		},
	)
	trainerHandler.SetPhotoStore(store)
	trainerHandler.SetClientProfileDeps(
		func(ctx context.Context, userID uuid.UUID) (*float64, *float64, error) {
			m, err := metricRepo.GetLatestByUserID(ctx, userID)
			if err != nil || m == nil {
				return nil, nil, err
			}
			return m.HeightCm, m.WeightKg, nil
		},
		func(ctx context.Context, userID uuid.UUID) (*float64, error) {
			list, err := bodyFatRepo.ListByUserID(ctx, userID, 1, 0)
			if err != nil || len(list) == 0 {
				return nil, err
			}
			return &list[0].BodyFatPct, nil
		},
		func(ctx context.Context, userID uuid.UUID, limit int) ([]trainerdelivery.ClientProfileMeasurement, error) {
			list, err := bodyMeasurementRepo.ListByUserID(ctx, userID, limit)
			if err != nil {
				return nil, err
			}
			out := make([]trainerdelivery.ClientProfileMeasurement, 0, len(list))
			for _, m := range list {
				out = append(out, trainerdelivery.ClientProfileMeasurement{
					ID:         m.ID.String(),
					RecordedAt: m.RecordedAt.Format(time.RFC3339),
					WeightKg:   m.WeightKg,
					BodyFatPct: m.BodyFatPct,
					HeightCm:   m.HeightCm,
				})
			}
			return out, nil
		},
		func(ctx context.Context, userID uuid.UUID) ([]trainerdelivery.PublicProfileGym, error) {
			gyms, err := gymUC.ListGymsByUserID(ctx, userID)
			if err != nil {
				return nil, err
			}
			out := make([]trainerdelivery.PublicProfileGym, 0, len(gyms))
			for _, g := range gyms {
				out = append(out, trainerdelivery.PublicProfileGym{ID: g.ID.String(), Name: g.Name, City: g.City})
			}
			return out, nil
		},
		func(ctx context.Context, userID uuid.UUID, limit, offset int) ([]map[string]interface{}, error) {
			list, err := workoutRepo.ListByUserID(ctx, userID, limit, offset, nil, nil)
			if err != nil {
				return nil, err
			}
			out := make([]map[string]interface{}, 0, len(list))
			for _, w := range list {
				m := map[string]interface{}{
					"id":         w.ID.String(),
					"user_id":    w.UserID.String(),
					"created_at": w.CreatedAt.Format(time.RFC3339),
				}
				if w.TemplateID != nil {
					m["template_id"] = w.TemplateID.String()
				}
				if w.ProgramID != nil {
					m["program_id"] = w.ProgramID.String()
				}
				if w.TrainerID != nil {
					m["trainer_id"] = w.TrainerID.String()
				}
				if w.ScheduledAt != nil {
					m["scheduled_at"] = w.ScheduledAt.Format(time.RFC3339)
				}
				if w.StartedAt != nil {
					m["started_at"] = w.StartedAt.Format(time.RFC3339)
				}
				if w.FinishedAt != nil {
					m["finished_at"] = w.FinishedAt.Format(time.RFC3339)
				}
				logs, _ := exerciseLogRepo.ListByWorkoutID(ctx, w.ID)
				var volume float64
				for _, l := range logs {
					if l.Reps != nil && l.WeightKg != nil && *l.Reps > 0 {
						volume += float64(*l.Reps) * *l.WeightKg
					}
				}
				m["volume_kg"] = volume
				out = append(out, m)
			}
			return out, nil
		},
	)

	trainerHandler.SetClientProgressDeps(
		func(ctx context.Context, userID uuid.UUID) ([]string, error) {
			ids, err := exerciseLogRepo.ListDistinctExerciseIDsForUser(ctx, userID)
			if err != nil {
				return nil, err
			}
			out := make([]string, 0, len(ids))
			for _, id := range ids {
				out = append(out, id.String())
			}
			return out, nil
		},
		func(ctx context.Context, userID, exerciseID uuid.UUID) ([]map[string]interface{}, error) {
			entries, err := exerciseLogRepo.ListVolumeHistoryByExerciseForUser(ctx, userID, exerciseID)
			if err != nil {
				return nil, err
			}
			out := make([]map[string]interface{}, 0, len(entries))
			for _, e := range entries {
				out = append(out, map[string]interface{}{
					"workout_id":   e.WorkoutID.String(),
					"workout_date": e.WorkoutDate.Format(time.RFC3339),
					"volume_kg":    e.VolumeKg,
				})
			}
			return out, nil
		},
	)
	trainerHandler.SetWorkoutUseCase(workoutUC)

	// Notification module
	notificationRepo := notificationrepository.NewNotificationRepository(db)
	notificationUC := notificationusecase.NewNotificationUseCase(notificationRepo)
	notificationHandler := notificationdelivery.NewHandler(notificationUC)

	// System messages module
	systemMessageRepo := systemmessagerepository.New(db)
	systemMessageUC := systemmessageusecase.New(systemMessageRepo)
	systemMessageHandler := systemmessagedelivery.NewHandler(systemMessageUC)

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
			ExercisesCount:  exerciseRepo.Count,
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
			SystemMessagesList: func(ctx context.Context, limit, offset int) ([]*systemmessagedomain.SystemMessage, error) {
				return systemMessageRepo.List(ctx, false, limit, offset)
			},
			SystemMessagesGet: systemMessageRepo.GetByID,
			SystemMessagesCreate: systemMessageRepo.Create,
			SystemMessagesUpdate: systemMessageRepo.Update,
			SystemMessagesDelete: systemMessageRepo.Delete,
			BucketsList:   bucketRepo.List,
			BucketsGet:    bucketRepo.GetByID,
			BucketsCreate: bucketRepo.Create,
			BucketsUpdate: bucketRepo.Update,
			BucketsDelete: bucketRepo.Delete,
			PhotosList: photoRepo.List,
			PhotosGet:  photoUC.GetByID,
			PhotosUpload: func(ctx context.Context, bucketName string, r io.Reader, contentType string) (uuid.UUID, string, error) {
				res, err := photoUC.Upload(ctx, bucketName, "admin", r, contentType, nil)
				if err != nil {
					return uuid.Nil, "", err
				}
				return res.PhotoID, res.URL, nil
			},
			PhotosDelete: photoUC.Delete,
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
		SystemMessageHandler: systemMessageHandler,
		GroupTrainingHandler: groupTrainingHandler,
		PhotoHandler:         photodelivery.NewHandler(photoUC),
		GamificationHandler:      gamificationHandler,
		GamificationAdminHandler: gamificationAdminHandler,
		AdminHandler:             adminHandler,
		JWTSecret:         []byte(cfg.JWTSecret),
		UploadsPath:       cfg.StoragePath,
	})

	// Background workers (in-process for now; split into separate worker cmd later)
	worker := workers.NewGymLoadSnapshotWorker(log, gymRepo, snapshotRepo, loadService, cfg.GymSnapshotInterval, cfg.GymSnapshotBatchSize)
	go worker.Run(ctx)

	go func() {
		ticker := time.NewTicker(30 * time.Second)
		defer ticker.Stop()
		for {
			select {
			case <-ctx.Done():
				return
			case <-ticker.C:
				_, _ = gamRepo.ProcessOutbox(context.Background(), 50)
			}
		}
	}()

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
