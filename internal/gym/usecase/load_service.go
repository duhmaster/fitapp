package usecase

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/redis/go-redis/v9"
)

// LoadService tracks gym load in real-time.
// Current approach: Redis ZSET per gym, members=user_id, score=unix seconds of last check-in.
// Load is computed as users with last check-in within presenceWindow.
type LoadService interface {
	CheckIn(ctx context.Context, gymID, userID uuid.UUID, at time.Time) (int, error)
	GetLoad(ctx context.Context, gymID uuid.UUID, now time.Time) (int, error)
}

type RedisLoadService struct {
	client         *redis.Client
	presenceWindow time.Duration
}

func NewRedisLoadService(client *redis.Client, presenceWindow time.Duration) *RedisLoadService {
	if presenceWindow <= 0 {
		presenceWindow = 90 * time.Minute
	}
	return &RedisLoadService{client: client, presenceWindow: presenceWindow}
}

func (s *RedisLoadService) CheckIn(ctx context.Context, gymID, userID uuid.UUID, at time.Time) (int, error) {
	key := presenceKey(gymID)
	score := float64(at.Unix())
	cutoff := float64(at.Add(-s.presenceWindow).Unix())

	pipe := s.client.Pipeline()
	pipe.ZAdd(ctx, key, redis.Z{Score: score, Member: userID.String()})
	pipe.ZRemRangeByScore(ctx, key, "-inf", fmt.Sprintf("%f", cutoff))
	cnt := pipe.ZCount(ctx, key, fmt.Sprintf("%f", cutoff), "+inf")
	_, err := pipe.Exec(ctx)
	if err != nil {
		return 0, err
	}
	n, err := cnt.Result()
	if err != nil {
		return 0, err
	}
	return int(n), nil
}

func (s *RedisLoadService) GetLoad(ctx context.Context, gymID uuid.UUID, now time.Time) (int, error) {
	key := presenceKey(gymID)
	cutoff := float64(now.Add(-s.presenceWindow).Unix())

	pipe := s.client.Pipeline()
	pipe.ZRemRangeByScore(ctx, key, "-inf", fmt.Sprintf("%f", cutoff))
	cnt := pipe.ZCount(ctx, key, fmt.Sprintf("%f", cutoff), "+inf")
	_, err := pipe.Exec(ctx)
	if err != nil {
		return 0, err
	}
	n, err := cnt.Result()
	if err != nil {
		return 0, err
	}
	return int(n), nil
}

func presenceKey(gymID uuid.UUID) string {
	return "gym:" + gymID.String() + ":presence"
}

