package config

import (
	"os"
	"testing"
)

func TestLoad(t *testing.T) {
	// Preserve and restore env to avoid affecting other tests
	orig := os.Getenv("PORT")
	defer func() {
		if orig != "" {
			os.Setenv("PORT", orig)
		} else {
			os.Unsetenv("PORT")
		}
	}()
	os.Unsetenv("PORT")

	cfg, err := Load()
	if err != nil {
		t.Fatalf("Load() error = %v", err)
	}
	if cfg == nil {
		t.Fatal("Load() returned nil config")
	}
	// Verify DSN is well-formed
	if dsn := cfg.DSN(); dsn == "" {
		t.Error("DSN() returned empty string")
	}
}

func TestDSN(t *testing.T) {
	cfg := &Config{
		DBUser:     "fitflow",
		DBPassword: "secret",
		DBHost:     "localhost",
		DBPort:     5432,
		DBName:     "fitflow",
		DBSSLMode:  "disable",
	}

	dsn := cfg.DSN()
	expected := "postgres://fitflow:secret@localhost:5432/fitflow?sslmode=disable"
	if dsn != expected {
		t.Errorf("DSN = %s, want %s", dsn, expected)
	}
}
