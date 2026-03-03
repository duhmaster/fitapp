package http

import (
	"net/http"

	"github.com/fitflow/fitflow/internal/auth/domain"
	authdelivery "github.com/fitflow/fitflow/internal/auth/delivery"
	gymdelivery "github.com/fitflow/fitflow/internal/gym/delivery"
	progressdelivery "github.com/fitflow/fitflow/internal/progress/delivery"
	userdelivery "github.com/fitflow/fitflow/internal/user/delivery"
	workoutdelivery "github.com/fitflow/fitflow/internal/workout/delivery"
	"github.com/fitflow/fitflow/internal/delivery/middleware"
	"github.com/gin-gonic/gin"
)

// RoutesConfig holds dependencies for route registration.
type RoutesConfig struct {
	HealthHandler   *HealthHandler
	AuthHandler     *authdelivery.Handler
	UserHandler     *userdelivery.Handler
	GymHandler      *gymdelivery.Handler
	WorkoutHandler  *workoutdelivery.Handler
	ProgressHandler *progressdelivery.Handler
	JWTSecret       []byte
	UploadsPath     string // local path for serving uploads (e.g. ./uploads)
}

// RegisterRoutes registers all HTTP routes with the given config.
func (s *Server) RegisterRoutes(cfg *RoutesConfig) {
	if cfg == nil || cfg.HealthHandler == nil {
		return
	}
	// Health endpoints for K8s probes
	s.router.GET("/health", cfg.HealthHandler.Health)
	s.router.GET("/health/ready", cfg.HealthHandler.Ready)
	s.router.GET("/health/live", cfg.HealthHandler.Live)

	// Static files (avatars, etc.)
	if cfg.UploadsPath != "" {
		s.router.Static("/uploads", cfg.UploadsPath)
	}

	// API v1
	v1 := s.router.Group("/api/v1")
	{
		v1.GET("/ping", func(c *gin.Context) {
			c.JSON(http.StatusOK, gin.H{"message": "pong"})
		})

		if cfg.AuthHandler != nil {
			auth := v1.Group("/auth")
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
			}

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
