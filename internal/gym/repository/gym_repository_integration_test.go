//go:build integration

package repository

import (
	"context"
	"os"
	"testing"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/google/uuid"
)

func TestGymRepository_CreateAndGet_Integration(t *testing.T) {
	dsn := os.Getenv("TEST_DB_DSN")
	if dsn == "" {
		t.Skip("TEST_DB_DSN not set")
	}

	ctx := context.Background()
	pool, err := pgxpool.New(ctx, dsn)
	if err != nil {
		t.Fatalf("pgxpool.New err = %v", err)
	}
	defer pool.Close()

	repo := NewGymRepository(pool)

	lat := 13.7563
	lng := 100.5018
	g, err := repo.Create(ctx, "Integration Gym "+uuid.NewString(), &lat, &lng, "Somewhere")
	if err != nil {
		t.Fatalf("Create err = %v", err)
	}

	got, err := repo.GetByID(ctx, g.ID)
	if err != nil {
		t.Fatalf("GetByID err = %v", err)
	}
	if got.ID != g.ID {
		t.Fatalf("ID mismatch got=%s want=%s", got.ID, g.ID)
	}
}

