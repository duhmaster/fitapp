package usecase

import (
	"context"
	"testing"
	"time"

	"github.com/alicebob/miniredis/v2"
	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

func TestRedisLoadService_CheckInAndGetLoad(t *testing.T) {
	mr, err := miniredis.Run()
	if err != nil {
		t.Fatalf("miniredis.Run() err = %v", err)
	}
	defer mr.Close()

	rdb := redis.NewClient(&redis.Options{Addr: mr.Addr()})
	defer rdb.Close()

	svc := NewRedisLoadService(rdb, 10*time.Second)
	gymID := uuid.New()
	u1 := uuid.New()
	u2 := uuid.New()

	t0 := time.Unix(1000, 0).UTC()
	if n, err := svc.CheckIn(context.Background(), gymID, u1, t0); err != nil || n != 1 {
		t.Fatalf("CheckIn u1 = (%d, %v), want (1, nil)", n, err)
	}

	if n, err := svc.CheckIn(context.Background(), gymID, u2, t0.Add(5*time.Second)); err != nil || n != 2 {
		t.Fatalf("CheckIn u2 = (%d, %v), want (2, nil)", n, err)
	}

	// After 11 seconds from t0, u1 should be outside the 10s presence window.
	if n, err := svc.GetLoad(context.Background(), gymID, t0.Add(11*time.Second)); err != nil || n != 1 {
		t.Fatalf("GetLoad = (%d, %v), want (1, nil)", n, err)
	}
}

