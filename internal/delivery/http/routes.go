package http

import (
	"net/http"
	"time"

	"github.com/fitflow/fitflow/internal/auth/domain"
	"github.com/fitflow/fitflow/internal/delivery/http/spec"
	authdelivery "github.com/fitflow/fitflow/internal/auth/delivery"
	"github.com/fitflow/fitflow/internal/pkg/version"
	blogdelivery "github.com/fitflow/fitflow/internal/blog/delivery"
	gymdelivery "github.com/fitflow/fitflow/internal/gym/delivery"
	progressdelivery "github.com/fitflow/fitflow/internal/progress/delivery"
	socialdelivery "github.com/fitflow/fitflow/internal/social/delivery"
	notificationdelivery "github.com/fitflow/fitflow/internal/notification/delivery"
	trainerdelivery "github.com/fitflow/fitflow/internal/trainer/delivery"
	userdelivery "github.com/fitflow/fitflow/internal/user/delivery"
	workoutdelivery "github.com/fitflow/fitflow/internal/workout/delivery"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	"github.com/gin-gonic/gin"
)

// RoutesConfig holds dependencies for route registration.
type RoutesConfig struct {
	// AllowedOrigins for CORS; nil = no CORS. Use []string{"*"} to allow all.
	AllowedOrigins []string
	HealthHandler  *HealthHandler
	AuthHandler     *authdelivery.Handler
	UserHandler     *userdelivery.Handler
	GymHandler      *gymdelivery.Handler
	WorkoutHandler  *workoutdelivery.Handler
	ProgressHandler *progressdelivery.Handler
	SocialHandler   *socialdelivery.Handler
	BlogHandler     *blogdelivery.Handler
	TrainerHandler     *trainerdelivery.Handler
	NotificationHandler *notificationdelivery.Handler
	JWTSecret          []byte
	UploadsPath     string // local path for serving uploads (e.g. ./uploads)
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
			}
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
					protected.GET("/users/me/metrics", cfg.UserHandler.GetMetrics)
					protected.GET("/users/me/metrics/history", cfg.UserHandler.GetMetricHistory)
					protected.POST("/users/me/metrics", cfg.UserHandler.RecordMetric)
				}

				if cfg.GymHandler != nil {
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
					protected.PATCH("/me/workouts/:workout_id/start", cfg.WorkoutHandler.StartWorkout)
					protected.PATCH("/me/workouts/:workout_id/finish", cfg.WorkoutHandler.FinishWorkout)
					protected.POST("/me/workouts/:workout_id/exercises", cfg.WorkoutHandler.AddExerciseToWorkout)
					protected.POST("/me/workouts/:workout_id/logs", cfg.WorkoutHandler.LogSet)
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
					protected.POST("/me/trainer/clients", cfg.TrainerHandler.AddClient)
					protected.PATCH("/me/trainer/clients/:client_id/status", cfg.TrainerHandler.SetClientStatus)
					protected.GET("/me/trainer/clients", cfg.TrainerHandler.ListMyClients)
					protected.GET("/me/trainers", cfg.TrainerHandler.ListMyTrainers)
					protected.POST("/me/trainer/programs", cfg.TrainerHandler.CreateProgram)
					protected.GET("/me/trainer/programs", cfg.TrainerHandler.ListMyPrograms)
					protected.GET("/me/programs", cfg.TrainerHandler.ListClientPrograms)
					protected.GET("/programs/:id", cfg.TrainerHandler.GetProgram)
					protected.PATCH("/me/trainer/programs/:program_id", cfg.TrainerHandler.UpdateProgram)
					protected.DELETE("/me/trainer/programs/:program_id", cfg.TrainerHandler.DeleteProgram)
					protected.POST("/me/trainer/clients/:client_id/comments", cfg.TrainerHandler.AddComment)
					protected.GET("/trainers/:trainer_id/clients/:client_id/comments", cfg.TrainerHandler.ListComments)
				}

				if cfg.NotificationHandler != nil {
					protected.GET("/me/notifications", cfg.NotificationHandler.List)
					protected.GET("/me/notifications/:notification_id", cfg.NotificationHandler.Get)
					protected.PATCH("/me/notifications/:notification_id/read", cfg.NotificationHandler.MarkRead)
					protected.PATCH("/me/notifications/read-all", cfg.NotificationHandler.MarkAllRead)
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
			}
		}
		}
	}
}
