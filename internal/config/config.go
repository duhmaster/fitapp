package config

import (
	"fmt"
	"os"
	"strconv"
	"time"
)

// Config holds all application configuration.
// Loaded from environment variables for 12-factor compatibility.
type Config struct {
	// Server
	Port              int
	Env               string
	CORSAllowedOrigins string // comma-separated; "*" = allow all; empty = no CORS

	// Database
	DBHost     string
	DBPort     int
	DBName     string
	DBUser     string
	DBPassword string
	DBSSLMode  string

	// Redis
	RedisAddr     string
	RedisPassword string
	RedisDB       int

	// JWT
	JWTSecret        string
	JWTAccessExpiry  time.Duration
	JWTRefreshExpiry time.Duration

	// Storage (for avatars, etc.)
	StoragePath  string
	StorageBaseURL string

	// Gym load tracking
	GymPresenceWindow   time.Duration
	GymSnapshotInterval time.Duration
	GymSnapshotBatchSize int

	// Admin panel (HTTP Basic or session; separate from app users)
	AdminUsername string
	AdminPassword string
}

// Load reads configuration from environment variables.
func Load() (*Config, error) {
	cfg := &Config{
		Port:               getEnvInt("PORT", 8080),
		Env:                getEnv("ENV", "development"),
		CORSAllowedOrigins: getEnv("CORS_ALLOWED_ORIGINS", corsDefault(getEnv("ENV", "development"))),
		DBHost:        getEnv("DB_HOST", "localhost"),
		DBPort:        getEnvInt("DB_PORT", 5432),
		DBName:        getEnv("DB_NAME", "fitflow"),
		DBUser:        getEnv("DB_USER", "fitflow"),
		DBPassword:    getEnv("DB_PASSWORD", ""),
		DBSSLMode:     getEnv("DB_SSLMODE", "disable"),
		RedisAddr:      getEnv("REDIS_ADDR", "localhost:6379"),
		RedisPassword:  getEnv("REDIS_PASSWORD", ""),
		RedisDB:        getEnvInt("REDIS_DB", 0),
		JWTSecret:        getEnv("JWT_SECRET", "change-me-in-production"),
		JWTAccessExpiry:  getEnvDuration("JWT_ACCESS_EXPIRY", 15*time.Minute),
		JWTRefreshExpiry: getEnvDuration("JWT_REFRESH_EXPIRY", 7*24*time.Hour),
		StoragePath:      getEnv("STORAGE_PATH", "./uploads"),
		StorageBaseURL:   getEnv("STORAGE_BASE_URL", "http://localhost:8080/uploads"),
		GymPresenceWindow:   getEnvDuration("GYM_PRESENCE_WINDOW", 90*time.Minute),
		GymSnapshotInterval: getEnvDuration("GYM_SNAPSHOT_INTERVAL", 5*time.Minute),
		GymSnapshotBatchSize: getEnvInt("GYM_SNAPSHOT_BATCH_SIZE", 1000),
		AdminUsername: getEnv("ADMIN_USERNAME", "admin"),
		AdminPassword: getEnv("ADMIN_PASSWORD", adminPasswordDefault(getEnv("ENV", "development"))),
	}

	return cfg, nil
}

// adminPasswordDefault: в development без ADMIN_PASSWORD включаем админку с паролем "admin".
func adminPasswordDefault(env string) string {
	if env == "development" {
		return "admin"
	}
	return ""
}

func getEnvDuration(key string, fallback time.Duration) time.Duration {
	if v := os.Getenv(key); v != "" {
		if d, err := time.ParseDuration(v); err == nil {
			return d
		}
	}
	return fallback
}

// DSN returns the PostgreSQL connection string.
func (c *Config) DSN() string {
	return fmt.Sprintf(
		"postgres://%s:%s@%s:%d/%s?sslmode=%s",
		c.DBUser, c.DBPassword, c.DBHost, c.DBPort, c.DBName, c.DBSSLMode,
	)
}

// corsDefault returns the default CORS allowed origins for the given env.
// In development, default to "*" so the Flutter web app and other local frontends work without config.
func corsDefault(env string) string {
	if env == "development" {
		return "*"
	}
	return ""
}

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if i, err := strconv.Atoi(v); err == nil {
			return i
		}
	}
	return fallback
}
