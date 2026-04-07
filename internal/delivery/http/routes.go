package http

import (
	"net/http"
	"time"

	"github.com/fitflow/fitflow/internal/admin"
	authdelivery "github.com/fitflow/fitflow/internal/auth/delivery"
	"github.com/fitflow/fitflow/internal/auth/domain"
	blogdelivery "github.com/fitflow/fitflow/internal/blog/delivery"
	"github.com/fitflow/fitflow/internal/delivery/http/spec"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	gamificationdelivery "github.com/fitflow/fitflow/internal/gamification/delivery"
	"github.com/fitflow/fitflow/internal/geo"
	grouptrainingdelivery "github.com/fitflow/fitflow/internal/grouptraining/delivery"
	gymdelivery "github.com/fitflow/fitflow/internal/gym/delivery"
	notificationdelivery "github.com/fitflow/fitflow/internal/notification/delivery"
	photodelivery "github.com/fitflow/fitflow/internal/photo/delivery"
	"github.com/fitflow/fitflow/internal/pkg/version"
	progressdelivery "github.com/fitflow/fitflow/internal/progress/delivery"
	socialdelivery "github.com/fitflow/fitflow/internal/social/delivery"
	systemmessagedelivery "github.com/fitflow/fitflow/internal/systemmessage/delivery"
	trainerdelivery "github.com/fitflow/fitflow/internal/trainer/delivery"
	userdelivery "github.com/fitflow/fitflow/internal/user/delivery"
	workoutdelivery "github.com/fitflow/fitflow/internal/workout/delivery"
	"github.com/gin-gonic/gin"
)

// RoutesConfig holds dependencies for route registration.
type RoutesConfig struct {
	// AllowedOrigins for CORS; nil = no CORS. Use []string{"*"} to allow all.
	AllowedOrigins           []string
	HealthHandler            *HealthHandler
	AuthHandler              *authdelivery.Handler
	UserHandler              *userdelivery.Handler
	GymHandler               *gymdelivery.Handler
	WorkoutHandler           *workoutdelivery.Handler
	ProgressHandler          *progressdelivery.Handler
	SocialHandler            *socialdelivery.Handler
	BlogHandler              *blogdelivery.Handler
	TrainerHandler           *trainerdelivery.Handler
	NotificationHandler      *notificationdelivery.Handler
	SystemMessageHandler     *systemmessagedelivery.Handler
	GroupTrainingHandler     *grouptrainingdelivery.Handler
	PhotoHandler             *photodelivery.Handler
	GamificationHandler      *gamificationdelivery.Handler
	GamificationAdminHandler *gamificationdelivery.AdminHandler
	AdminHandler             *admin.Handler
	JWTSecret                []byte
	UploadsPath              string      // local path for serving uploads (e.g. ./uploads)
	GeoClient                *geo.Client // 2GIS proxy for cities/organizations (optional)
}

// RegisterRoutes registers all HTTP routes with the given config.
func (s *Server) RegisterRoutes(cfg *RoutesConfig) {
	if cfg == nil || cfg.HealthHandler == nil {
		return
	}
	if cfg.AllowedOrigins != nil {
		s.router.Use(middleware.CORS(cfg.AllowedOrigins))
	}
	// Health and version (no auth)
	s.router.GET("/health", cfg.HealthHandler.Health)
	s.router.GET("/health/ready", cfg.HealthHandler.Ready)
	s.router.GET("/health/live", cfg.HealthHandler.Live)
	s.router.GET("/version", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"version": version.Version})
	})

	// Static files (avatars, etc.)
	if cfg.UploadsPath != "" {
		s.router.Static("/uploads", cfg.UploadsPath)
	}

	// OpenAPI spec (no auth)
	s.router.GET("/openapi.yaml", func(c *gin.Context) {
		c.Data(http.StatusOK, "application/yaml; charset=utf-8", spec.OpenAPIYAML)
	})

	// Admin panel: localhost:port/admin or adm.gymmore.ru (nginx routes same backend)
	if cfg.AdminHandler != nil {
		adminGroup := s.router.Group("/admin")
		admin.RegisterRoutes(adminGroup, cfg.AdminHandler)
	}

	// API v1 (30s request timeout for handlers that use context)
	v1 := s.router.Group("/api/v1")
	v1.Use(middleware.Timeout(30 * time.Second))
	{
		v1.GET("/ping", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"message": "pong"})
		})

		v1.GET("/locales", listLocales)
		v1.GET("/locales/:lang", getLocale)

		if cfg.AuthHandler != nil {
			auth := v1.Group("/auth")
			auth.Use(middleware.RateLimit(20, 60*time.Second)) // 20 req/min per IP for auth
			{
				auth.POST("/register", cfg.AuthHandler.Register)
				auth.POST("/login", cfg.AuthHandler.Login)
				auth.POST("/refresh", cfg.AuthHandler.Refresh)
			}
		}

		if cfg.GymHandler != nil {
			gyms := v1.Group("/gyms")
			{
				gyms.GET("", cfg.GymHandler.SearchGyms)
				gyms.GET("/:gym_id/load", cfg.GymHandler.GetLoad)
				gyms.GET("/:gym_id/load/history", cfg.GymHandler.GetLoadHistory)
				if cfg.GroupTrainingHandler != nil {
					gyms.GET("/:gym_id/trainers", cfg.GroupTrainingHandler.ListTrainersAtGym)
					gyms.GET("/:gym_id/group-trainings", cfg.GroupTrainingHandler.ListGroupTrainingsByGym)
				}
			}
		}

		// Public trainer profile (no auth) — GET /api/v1/trainers/:user_id
		if cfg.TrainerHandler != nil {
			v1.GET("/trainers/:user_id", cfg.TrainerHandler.GetTrainerPublic)
		}

		// Public group training landing (no auth) — GET /api/v1/group-trainings/:training_id
		if cfg.GroupTrainingHandler != nil {
			v1.GET("/group-trainings/:training_id", cfg.GroupTrainingHandler.GetPublicGroupTraining)
			v1.GET("/trainers/:user_id/group-trainings/upcoming", cfg.GroupTrainingHandler.ListUpcomingForTrainerPublic)
		}

		if cfg.GamificationHandler != nil {
			v1.GET("/gamification/leaderboards/public", cfg.GamificationHandler.GetPublicLeaderboard)
		}

		if len(cfg.JWTSecret) > 0 && cfg.AuthHandler != nil {
			protected := v1.Group("")
			protected.Use(middleware.JWTAuth(cfg.JWTSecret))
			{
				protected.GET("/me", cfg.AuthHandler.Me)
				protected.PATCH("/me/preferences", cfg.AuthHandler.PatchMePreferences)

				if cfg.UserHandler != nil {
					protected.GET("/users/me/profile", cfg.UserHandler.GetProfile)
					protected.PUT("/users/me/profile", cfg.UserHandler.UpdateProfile)
					protected.POST("/users/me/avatar", cfg.UserHandler.UploadAvatar)
					protected.DELETE("/users/me/avatar", cfg.UserHandler.DeleteAvatar)
					protected.GET("/users/me/metrics", cfg.UserHandler.GetMetrics)
					protected.GET("/users/me/metrics/history", cfg.UserHandler.GetMetricHistory)
					protected.POST("/users/me/metrics", cfg.UserHandler.RecordMetric)
					protected.GET("/users/me/body-measurements", cfg.UserHandler.ListBodyMeasurements)
					protected.POST("/users/me/body-measurements", cfg.UserHandler.CreateBodyMeasurement)
					protected.PUT("/users/me/body-measurements/:id", cfg.UserHandler.UpdateBodyMeasurement)
					protected.DELETE("/users/me/body-measurements/:id", cfg.UserHandler.DeleteBodyMeasurement)
				}

				if cfg.GeoClient != nil {
					geo.RegisterRoutes(protected.Group("/geo"), cfg.GeoClient)
				}

				if cfg.GymHandler != nil {
					protected.GET("/me/gyms", cfg.GymHandler.ListMyGyms)
					protected.POST("/me/gyms", cfg.GymHandler.AddMyGym)
					protected.GET("/me/gyms/:gym_id", cfg.GymHandler.GetMyGym)
					protected.DELETE("/me/gyms/:gym_id", cfg.GymHandler.RemoveMyGym)
					protected.POST("/gyms/:gym_id/checkins", cfg.GymHandler.CheckIn)
				}

				if cfg.WorkoutHandler != nil {
					protected.GET("/exercises", cfg.WorkoutHandler.ListExercises)
					protected.GET("/programs", cfg.WorkoutHandler.ListPrograms)
					protected.POST("/programs", cfg.WorkoutHandler.CreateProgram)
					protected.GET("/programs/:id/exercises", cfg.WorkoutHandler.GetProgramExercises)
					protected.POST("/workouts/start", cfg.WorkoutHandler.StartWorkoutFromProgram)
					protected.GET("/me/workouts", cfg.WorkoutHandler.ListMyWorkouts)
					protected.POST("/me/workouts", cfg.WorkoutHandler.CreateWorkout)
					protected.GET("/me/workouts/:workout_id", cfg.WorkoutHandler.GetWorkout)
					protected.DELETE("/me/workouts/:workout_id", cfg.WorkoutHandler.DeleteWorkout)
					protected.PATCH("/me/workouts/:workout_id/start", cfg.WorkoutHandler.StartWorkout)
					protected.PATCH("/me/workouts/:workout_id/finish", cfg.WorkoutHandler.FinishWorkout)
					protected.POST("/me/workouts/:workout_id/exercises", cfg.WorkoutHandler.AddExerciseToWorkout)
					protected.POST("/me/workouts/:workout_id/logs", cfg.WorkoutHandler.LogSet)
					// Workout templates (literal "exercises" routes before :template_id to avoid matching)
					protected.GET("/me/workout-templates", cfg.WorkoutHandler.ListTemplates)
					protected.POST("/me/workout-templates", cfg.WorkoutHandler.CreateTemplate)
					protected.DELETE("/me/workout-templates/exercises/:template_exercise_id", cfg.WorkoutHandler.RemoveExerciseFromTemplate)
					protected.POST("/me/workout-templates/exercises/:template_exercise_id/sets", cfg.WorkoutHandler.AddSetToTemplateExercise)
					protected.DELETE("/me/workout-templates/exercises/:template_exercise_id/sets/:set_id", cfg.WorkoutHandler.DeleteTemplateSet)
					protected.GET("/me/workout-templates/:template_id", cfg.WorkoutHandler.GetTemplate)
					protected.PUT("/me/workout-templates/:template_id", cfg.WorkoutHandler.UpdateTemplate)
					protected.DELETE("/me/workout-templates/:template_id", cfg.WorkoutHandler.DeleteTemplate)
					protected.POST("/me/workout-templates/:template_id/exercises", cfg.WorkoutHandler.AddExerciseToTemplate)
					protected.PUT("/me/workout-templates/:template_id/reorder", cfg.WorkoutHandler.ReorderTemplateExercises)
					protected.POST("/me/workout-templates/:template_id/start", cfg.WorkoutHandler.StartWorkoutFromTemplate)
					protected.GET("/me/progress/exercise-ids", cfg.WorkoutHandler.ListProgressExerciseIDs)
					protected.GET("/me/progress/exercises/:exercise_id/volume-history", cfg.WorkoutHandler.ListExerciseVolumeHistory)
				}

				if cfg.ProgressHandler != nil {
					protected.POST("/me/weight", cfg.ProgressHandler.RecordWeight)
					protected.GET("/me/weight/history", cfg.ProgressHandler.ListWeightHistory)
					protected.POST("/me/body-fat", cfg.ProgressHandler.RecordBodyFat)
					protected.GET("/me/body-fat/history", cfg.ProgressHandler.ListBodyFatHistory)
					protected.POST("/me/health-metrics", cfg.ProgressHandler.RecordHealthMetric)
					protected.GET("/me/health-metrics", cfg.ProgressHandler.ListHealthMetrics)
				}

				if cfg.SocialHandler != nil {
					protected.POST("/me/follow/:user_id", cfg.SocialHandler.Follow)
					protected.DELETE("/me/follow/:user_id", cfg.SocialHandler.Unfollow)
					protected.GET("/me/following", cfg.SocialHandler.ListFollowing)
					protected.GET("/me/followers", cfg.SocialHandler.ListFollowers)
					protected.POST("/me/friend-requests", cfg.SocialHandler.CreateFriendRequest)
					protected.GET("/me/friend-requests/incoming", cfg.SocialHandler.ListIncomingFriendRequests)
					protected.GET("/me/friend-requests/outgoing", cfg.SocialHandler.ListOutgoingFriendRequests)
					protected.PATCH("/me/friend-requests/:request_id/accept", cfg.SocialHandler.AcceptFriendRequest)
					protected.PATCH("/me/friend-requests/:request_id/reject", cfg.SocialHandler.RejectFriendRequest)
					protected.POST("/me/posts", cfg.SocialHandler.CreatePost)
					protected.GET("/me/feed", cfg.SocialHandler.GetFeed)
					protected.GET("/users/:user_id/posts", cfg.SocialHandler.ListUserPosts)
					protected.GET("/posts/:post_id", cfg.SocialHandler.GetPost)
					protected.POST("/posts/:post_id/like", cfg.SocialHandler.LikePost)
					protected.DELETE("/posts/:post_id/like", cfg.SocialHandler.UnlikePost)
					protected.GET("/posts/:post_id/likes", cfg.SocialHandler.GetPostLikes)
					protected.POST("/posts/:post_id/comments", cfg.SocialHandler.AddComment)
					protected.GET("/posts/:post_id/comments", cfg.SocialHandler.ListComments)
				}

				if cfg.BlogHandler != nil {
					protected.POST("/me/blog-posts", cfg.BlogHandler.CreatePost)
					protected.GET("/me/blog-posts", cfg.BlogHandler.ListMyPosts)
					protected.PATCH("/me/blog-posts/:post_id", cfg.BlogHandler.UpdatePost)
					protected.DELETE("/me/blog-posts/:post_id", cfg.BlogHandler.DeletePost)
					protected.POST("/me/blog-posts/:post_id/photos", cfg.BlogHandler.AddPhoto)
					protected.DELETE("/me/blog-posts/:post_id/photos/:photo_id", cfg.BlogHandler.DeletePhoto)
					protected.POST("/me/blog-posts/:post_id/tags/:tag_id", cfg.BlogHandler.AddTagToPost)
					protected.DELETE("/me/blog-posts/:post_id/tags/:tag_id", cfg.BlogHandler.RemoveTagFromPost)
					protected.POST("/tags", cfg.BlogHandler.CreateTag)
				}

				if cfg.TrainerHandler != nil {
					protected.GET("/me/trainer/profile", cfg.TrainerHandler.GetMyTrainerProfile)
					protected.PUT("/me/trainer/profile", cfg.TrainerHandler.UpdateMyTrainerProfile)
					protected.GET("/me/trainer/photos", cfg.TrainerHandler.ListMyTrainerPhotos)
					protected.POST("/me/trainer/photos", cfg.TrainerHandler.UploadTrainerPhoto)
					protected.DELETE("/me/trainer/photos/:photo_id", cfg.TrainerHandler.DeleteTrainerPhoto)
					protected.POST("/me/trainer/clients", cfg.TrainerHandler.AddClient)
					protected.PATCH("/me/trainer/clients/:client_id/status", cfg.TrainerHandler.SetClientStatus)
					protected.GET("/me/trainer/clients", cfg.TrainerHandler.ListMyClients)
					protected.DELETE("/me/trainer/clients/:client_id", cfg.TrainerHandler.RemoveClient)
					protected.GET("/me/trainer/clients/:client_id/profile", cfg.TrainerHandler.GetClientProfile)
					protected.GET("/me/trainer/clients/:client_id/progress/exercise-ids", cfg.TrainerHandler.GetClientProgressExerciseIDs)
					protected.GET("/me/trainer/clients/:client_id/progress/exercises/:exercise_id/volume-history", cfg.TrainerHandler.GetClientExerciseVolumeHistory)
					protected.GET("/me/trainer/clients/:client_id/templates", cfg.TrainerHandler.ListClientTemplates)
					protected.POST("/me/trainer/clients/:client_id/templates", cfg.TrainerHandler.CreateClientTemplate)
					protected.POST("/me/trainer/clients/:client_id/workouts", cfg.TrainerHandler.CreateClientWorkout)
					protected.GET("/me/trainers", cfg.TrainerHandler.ListMyTrainers)
					protected.POST("/me/trainers", cfg.TrainerHandler.AddMyTrainer)
					protected.DELETE("/me/trainers/:trainer_id", cfg.TrainerHandler.RemoveMyTrainer)
					protected.GET("/trainers", cfg.TrainerHandler.SearchTrainers)
					protected.GET("/me/trainer/workouts", cfg.WorkoutHandler.ListMyTrainerWorkouts)
					protected.POST("/me/trainer/programs", cfg.TrainerHandler.CreateProgram)
					protected.GET("/me/trainer/programs", cfg.TrainerHandler.ListMyPrograms)
					protected.GET("/me/programs", cfg.TrainerHandler.ListClientPrograms)
					protected.GET("/programs/:id", cfg.TrainerHandler.GetProgram)
					protected.PATCH("/me/trainer/programs/:program_id", cfg.TrainerHandler.UpdateProgram)
					protected.DELETE("/me/trainer/programs/:program_id", cfg.TrainerHandler.DeleteProgram)
					protected.POST("/me/trainer/clients/:client_id/comments", cfg.TrainerHandler.AddComment)
					protected.GET("/trainers/:user_id/clients/:client_id/comments", cfg.TrainerHandler.ListComments)
				}

				if cfg.NotificationHandler != nil {
					protected.GET("/me/notifications", cfg.NotificationHandler.List)
					protected.GET("/me/notifications/:notification_id", cfg.NotificationHandler.Get)
					protected.PATCH("/me/notifications/:notification_id/read", cfg.NotificationHandler.MarkRead)
					protected.PATCH("/me/notifications/read-all", cfg.NotificationHandler.MarkAllRead)
				}

				if cfg.SystemMessageHandler != nil {
					protected.GET("/me/system-messages", cfg.SystemMessageHandler.ListActive)
					protected.GET("/me/system-messages/count", cfg.SystemMessageHandler.CountActive)
				}

				if cfg.PhotoHandler != nil {
					protected.POST("/me/photos/upload", cfg.PhotoHandler.Upload)
				}

				if cfg.GamificationHandler != nil {
					g := cfg.GamificationHandler
					protected.GET("/me/gamification/preferences", g.GetFeaturePreferences)
					protected.PATCH("/me/gamification/preferences", g.PatchFeaturePreferences)
					protected.GET("/me/gamification/profile", g.GetProfile)
					protected.GET("/me/gamification/xp-history", g.GetXPHistory)
					protected.GET("/me/gamification/badges/catalog", g.GetBadgeCatalog)
					protected.GET("/me/gamification/badges", g.GetUserBadges)
					protected.GET("/me/gamification/missions", g.GetMissions)
					protected.GET("/me/gamification/missions/progress", g.GetMissionProgress)
					protected.POST("/me/gamification/missions/:mission_id/claim", g.ClaimMission)
					protected.GET("/me/gamification/leaderboards", g.GetLeaderboards)
				}

				// Group trainings
				if cfg.GroupTrainingHandler != nil {
					protected.GET("/me/group-training-types", cfg.GroupTrainingHandler.ListTypes)

					// Trainer templates
					protected.GET("/me/trainer/group-training-templates", cfg.GroupTrainingHandler.ListTrainerTemplates)
					protected.POST("/me/trainer/group-training-templates", cfg.GroupTrainingHandler.CreateTrainerTemplate)
					protected.GET("/me/trainer/group-training-templates/:template_id", cfg.GroupTrainingHandler.GetTrainerTemplate)
					protected.PUT("/me/trainer/group-training-templates/:template_id", cfg.GroupTrainingHandler.UpdateTrainerTemplate)
					protected.DELETE("/me/trainer/group-training-templates/:template_id", cfg.GroupTrainingHandler.SoftDeleteTrainerTemplate)

					// Trainer trainings
					protected.GET("/me/trainer/group-trainings", cfg.GroupTrainingHandler.ListTrainerTrainings)
					protected.POST("/me/trainer/group-trainings", cfg.GroupTrainingHandler.CreateTrainerTraining)
					protected.PUT("/me/trainer/group-trainings/:training_id", cfg.GroupTrainingHandler.UpdateTrainerTraining)
					protected.GET("/me/trainer/group-trainings/:training_id", cfg.GroupTrainingHandler.GetTrainerTraining)
					protected.DELETE("/me/trainer/group-trainings/:training_id", cfg.GroupTrainingHandler.DeleteTrainerTraining)

					// User trainings
					protected.GET("/me/group-trainings/available", cfg.GroupTrainingHandler.ListAvailableForUser)
					protected.GET("/me/group-trainings", cfg.GroupTrainingHandler.ListUserTrainings)
					protected.GET("/me/group-trainings/:training_id", cfg.GroupTrainingHandler.GetUserTraining)
					protected.POST("/me/group-trainings/:training_id/register", cfg.GroupTrainingHandler.RegisterForTraining)
					protected.DELETE("/me/group-trainings/:training_id/register", cfg.GroupTrainingHandler.UnregisterFromTraining)
				}
			}

			if cfg.BlogHandler != nil {
				blog := v1.Group("/blog-posts")
				{
					blog.GET("", cfg.BlogHandler.ListPosts)
					blog.GET("/:post_id", cfg.BlogHandler.GetPost)
				}
				tags := v1.Group("/tags")
				{
					tags.GET("", cfg.BlogHandler.ListTags)
				}
			}

			if len(cfg.JWTSecret) > 0 && cfg.AuthHandler != nil {
				admin := v1.Group("/admin")
				admin.Use(middleware.JWTAuth(cfg.JWTSecret))
				admin.Use(middleware.RequireRole(domain.RoleAdmin))
				{
					admin.GET("/ping", func(c *gin.Context) {
						c.JSON(http.StatusOK, gin.H{"message": "admin pong"})
					})

					if cfg.GymHandler != nil {
						admin.POST("/gyms", cfg.GymHandler.CreateGym)
					}

					if cfg.GamificationAdminHandler != nil {
						gam := cfg.GamificationAdminHandler
						ag := admin.Group("/gamification")
						ag.GET("/settings", gam.GetSettings)
						ag.PATCH("/settings/:key", gam.PatchSetting)
						ag.GET("/levels", gam.GetLevels)
						ag.PATCH("/levels", gam.PatchLevels)
						ag.GET("/badges", gam.ListBadges)
						ag.POST("/badges", gam.CreateBadge)
						ag.PATCH("/badges/:id", gam.UpdateBadge)
						ag.DELETE("/badges/:id", gam.DeleteBadge)
						ag.GET("/missions", gam.ListMissions)
						ag.POST("/missions", gam.CreateMission)
						ag.PATCH("/missions/:id", gam.UpdateMission)
						ag.DELETE("/missions/:id", gam.DeleteMission)
					}
				}
			}
		}
	}
}
